/**
 * Owner delete on `venueEvents` — the parity gap.
 *
 * Offers and PinBoxes have had `allow delete: if owner` from the start.
 * Events had `allow delete: if false` and only a `cancelled` status, so
 * a venue could not remove an event posted by mistake in ANY state.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const OWNER = "ev-owner";
const OTHER = "ev-other";
const VENUE = "ev-venue";

const STATUSES = ["upcoming", "live", "past", "cancelled"] as const;

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const u of [OWNER, OTHER]) await setDoc(doc(fs, "users", u), userFixture(u));
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, { category: "restaurant" }));
  });
});
after(async () => { await env.cleanup(); });

async function seed(id: string, status: string) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "venueEvents", id), {
      venueId: VENUE, title: "T", description: "D", status,
      startAt: new Date(), endAt: new Date(), category: "concert", createdAt: new Date(),
    });
  });
}

describe("tədbir silmə — sahib HƏR statusda silə bilir", () => {
  for (const status of STATUSES) {
    test(`sahib "${status}" tədbiri silir`, async () => {
      const id = `ev-${status}`;
      await seed(id, status);
      const db = env.authenticatedContext(OWNER).firestore();
      await assertSucceeds(deleteDoc(doc(db, "venueEvents", id)));
    });
  }

  test("`live` də daxil — UI xəbərdarlıq edir, qayda bloklamır", async () => {
    // Məhsul qərarı: sahib öz məzmununun sahibidir. Qoruma
    // `_confirmDelete`-in dialoqudur, qadağa deyil.
    await seed("ev-live-2", "live");
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(deleteDoc(doc(db, "venueEvents", "ev-live-2")));
  });
});

describe("tədbir silmə — başqası silə bilmir", () => {
  test("kənar istifadəçi RƏDD", async () => {
    await seed("ev-x1", "upcoming");
    const db = env.authenticatedContext(OTHER).firestore();
    await assertFails(deleteDoc(doc(db, "venueEvents", "ev-x1")));
  });

  test("imzasız istifadəçi RƏDD", async () => {
    await seed("ev-x2", "upcoming");
    const db = env.unauthenticatedContext().firestore();
    await assertFails(deleteDoc(doc(db, "venueEvents", "ev-x2")));
  });

  test("başqa məkanın sahibi RƏDD", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", "ev-venue2"), venueFixture(OTHER, { category: "restaurant" }));
      await setDoc(doc(ctx.firestore(), "venueEvents", "ev-x3"), {
        venueId: "ev-venue2", title: "T", description: "D", status: "upcoming",
        startAt: new Date(), endAt: new Date(), category: "concert", createdAt: new Date(),
      });
    });
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(deleteDoc(doc(db, "venueEvents", "ev-x3")));
  });
});
