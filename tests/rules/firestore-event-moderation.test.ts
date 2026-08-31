/**
 * Trust-based event moderation, at the rules boundary.
 *
 * The design's load-bearing claim is that the CLIENT never decides
 * whether an event publishes. It writes `pending`, always, and
 * `onVenueEventCreated` flips a trusted venue's event to `upcoming`
 * inside a transaction.
 *
 * That inversion exists because the obvious alternative — a rule
 * reading `publishedEventCount` and allowing `upcoming` above the
 * threshold — cannot be made safe: rules have no transactions, so a
 * brand-new venue could create ten events against the same stale read
 * before the first increment landed. These tests pin the rule half of
 * that: no client-written `upcoming`, ever, and no self-approval later.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const OWNER = "em-owner";
const OTHER = "em-other";
const VENUE = "em-venue";

function eventDoc(overrides: Record<string, unknown> = {}) {
  return {
    venueId: VENUE, title: "Tədbir", description: "T", status: "pending",
    startAt: new Date(Date.now() + 3600_000), endAt: new Date(Date.now() + 7200_000),
    category: "concert", createdAt: new Date(), ...overrides,
  };
}

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const u of [OWNER, OTHER]) await setDoc(doc(fs, "users", u), userFixture(u));
    // A venue well past the trust threshold — proving the rule does not
    // consult it is the point.
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, {
      category: "restaurant", status: "approved", publishedEventCount: 99,
      subscriptionRenewsAt: new Date(Date.now() + 20 * 24 * 3600_000),
    }));
    for (const [id, status] of [["em-pending", "pending"], ["em-live", "upcoming"], ["em-rejected", "rejected"]]) {
      await setDoc(doc(fs, "venueEvents", id), eventDoc({ status }));
    }
  });
});
after(async () => { await env.cleanup(); });

describe("klient yalnız `pending` yarada bilir", () => {
  test("`pending` qəbul edilir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(doc(db, "venueEvents", "em-new-ok"), eventDoc()));
  });

  test("`upcoming` RƏDD edilir — etimadlı məkanda belə", async () => {
    // publishedEventCount 99-dur. Qayda onu OXUMUR, çünki oxusaydı
    // yarış vəziyyəti yaranardı: qayda tranzaksiya edə bilmir, sayğacı
    // isə trigger artırır. Qərar `onVenueEventCreated`-dədir.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(setDoc(doc(db, "venueEvents", "em-new-up"), eventDoc({ status: "upcoming" })));
  });

  for (const status of ["live", "ended", "rejected", "cancelled"]) {
    test(`"${status}" ilə yaratmaq rədd edilir`, async () => {
      const db = env.authenticatedContext(OWNER).firestore();
      await assertFails(setDoc(doc(db, "venueEvents", `em-new-${status}`), eventDoc({ status })));
    });
  }

  test("özgə məkanına tədbir yaratmaq rədd edilir", async () => {
    const db = env.authenticatedContext(OTHER).firestore();
    await assertFails(setDoc(doc(db, "venueEvents", "em-new-foreign"), eventDoc()));
  });
});

describe("sahib öz tədbirini təsdiqləyə bilmir", () => {
  test("`pending` → `upcoming` sahib tərəfindən RƏDD edilir", async () => {
    // Bu olmasaydı, ön-moderasiya bir sətirlik update ilə keçilərdi.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venueEvents", "em-pending"), { status: "upcoming" }));
  });

  test("`pending` → `cancelled` icazəlidir — ləğv sahibin haqqıdır", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, "venueEvents", "em-pending"), { status: "cancelled" }));
  });

  test("`rejected` → `upcoming` rədd edilir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venueEvents", "em-rejected"), { status: "upcoming" }));
  });
});

describe("məzmun redaktəsi", () => {
  test("`pending` tədbir redaktə edilə bilir — baxış gözləyərkən düzəliş", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venueEvents", "em-edit"), eventDoc());
    });
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, "venueEvents", "em-edit"), { title: "Düzəldilmiş" }));
  });

  test("`rejected` tədbir redaktə edilə bilmir — qərarın yan keçilməsi", async () => {
    // Rədd edilmiş tədbiri redaktə ilə forma salmaq moderatorun
    // qərarını yan keçmək olardı; yenidən yaratmaq bir toxunuşdur.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venueEvents", "em-rejected"), { title: "Yenidən" }));
  });
});

describe("etimad və kvota sayğacları server-only-dir", () => {
  for (const field of ["publishedEventCount", "freeEventsUsed", "freeEventPeriodStart"]) {
    test(`sahib ${field} yaza bilmir`, async () => {
      // publishedEventCount yazıla bilsəydi, məkan özünü bir yazı ilə
      // "etimadlı" edib ön-moderasiyadan tamamilə çıxardı.
      const db = env.authenticatedContext(OWNER).firestore();
      await assertFails(updateDoc(doc(db, "venues", VENUE), { [field]: 999 }));
    });
  }
});
