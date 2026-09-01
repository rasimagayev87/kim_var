/**
 * The free-campaign quota's client-side surface, and the venue-status
 * gate on the two listing paths that write straight from the client.
 *
 * ── Why these two things share a file ──────────────────────────────
 *
 * They are the same finding. `submitOffer` checked venue ownership and
 * nothing else, so a venue that was suspended for non-payment could
 * still publish; the identical gap existed in `pinboxes` and
 * `venueEvents` create, which never went through a callable at all.
 * The quota makes that gap expensive rather than merely wrong — an
 * unpaid venue drawing the allowance its subscription is what pays
 * for — so the counter and the gate are tested together.
 *
 * `venueEvents` is the sharpest case: events have no moderation step,
 * so a suspended venue's event went straight into discovery AND into
 * the daily digest push.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const OWNER = "cq-owner";
const APPROVED = "cq-venue-approved";

/** Every status a venue can be in that is NOT publishable. */
const DEAD_STATUSES = ["pending", "rejected", "needs_revision", "awaiting_payment", "subscription_overdue"] as const;

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
    await setDoc(doc(fs, "venues", APPROVED), venueFixture(OWNER, {
      category: "restaurant",
      status: "approved",
      freeCampaignsUsed: 2,
      createdAt: new Date("2026-01-01"),
    }));
    for (const status of DEAD_STATUSES) {
      await setDoc(doc(fs, "venues", `cq-venue-${status}`), venueFixture(OWNER, { category: "restaurant", status }));
    }
  });
});
after(async () => { await env.cleanup(); });

describe("kvota sayğacı server-only-dir", () => {
  test("sahib freeCampaignsUsed-i azalda bilmir", async () => {
    // Bloklistdə olmasaydı, sahib sayğacı sıfırlayıb limitsiz pulsuz
    // kampaniya yarada bilərdi — kvotanın bütün mənası bu bir sətirdir.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", APPROVED), { freeCampaignsUsed: 0 }));
  });

  test("sahib freeCampaignPeriodStart-ı irəli sürə bilmir", async () => {
    // Dövrün başını dəyişmək sayğacı "köhnəlmiş" göstərib serverdə
    // sıfırlanmaya səbəb olardı — eyni nəticə, dolayı yolla.
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", APPROVED), { freeCampaignPeriodStart: new Date() }));
  });

  test("sahib createdAt-ı dəyişə bilmir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", APPROVED), { createdAt: new Date("2020-01-01") }));
  });

  test("icazəli sahə hələ də yazıla bilir — bloklist hər şeyi bağlamayıb", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(doc(db, "venues", APPROVED), { waitlistEnabled: true }));
  });
});

describe("dayandırılmış məkan elan yaya bilmir — PinBox", () => {
  function pinboxDoc(venueId: string) {
    return {
      ownerId: OWNER, venueId, title: "Qutu", description: "T", status: "pending",
      stockTotal: 3, stockRemaining: 3, price: 5,
      pickupWindowStart: new Date(), pickupWindowEnd: new Date(Date.now() + 3600_000),
      createdAt: new Date(),
    };
  }

  test("təsdiqlənmiş məkan qutu yarada bilir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(doc(db, "pinboxes", "cq-pb-ok"), pinboxDoc(APPROVED)));
  });

  for (const status of DEAD_STATUSES) {
    test(`"${status}" statuslu məkan qutu yarada bilmir`, async () => {
      const db = env.authenticatedContext(OWNER).firestore();
      await assertFails(setDoc(doc(db, "pinboxes", `cq-pb-${status}`), pinboxDoc(`cq-venue-${status}`)));
    });
  }
});

describe("dayandırılmış məkan elan yaya bilmir — tədbir", () => {
  function eventDoc(venueId: string) {
    return {
      // `pending` — firestore.rules accepts no other value from a
      // client now, see firestore-event-moderation.test.ts.
      venueId, title: "Tədbir", description: "T", status: "pending",
      startAt: new Date(Date.now() + 3600_000), endAt: new Date(Date.now() + 7200_000),
      category: "concert", createdAt: new Date(),
    };
  }

  test("təsdiqlənmiş məkan tədbir yarada bilir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(doc(db, "venueEvents", "cq-ev-ok"), eventDoc(APPROVED)));
  });

  for (const status of DEAD_STATUSES) {
    test(`"${status}" statuslu məkan tədbir yarada bilmir`, async () => {
      // Tədbirin moderasiyası yoxdur — yaradıldığı an Canlı feed-ə və
      // gündəlik digest push-una düşür. Yəni bu yolda qayda yeganə
      // müdafiədir; təklif və qutuda arxada moderasiya var.
      const db = env.authenticatedContext(OWNER).firestore();
      await assertFails(setDoc(doc(db, "venueEvents", `cq-ev-${status}`), eventDoc(`cq-venue-${status}`)));
    });
  }
});

describe("A5-C1 — kvota hold bayrağı server-only-dir", () => {
  // Bu, blocklist boşluğu idi: `freeCampaignHold` siyahıda yox idi,
  // yəni yazıla bilirdi. İstismar dövrü — pulsuz kampaniya yarat,
  // təsdiqlən (bayraq silinir, slot həmişəlik tutulur), bayrağı GERİ
  // YAZ, sil (trigger bayrağı görüb slotu qaytarır), təkrarla.
  // Nəticə: limitsiz pulsuz kampaniya.
  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "offers", "cq-offer"), {
        ownerId: OWNER, venueId: APPROVED, status: "approved", title: "T", description: "D",
        offerType: "discount", startDate: new Date(), endDate: new Date(Date.now() + 86400000),
        category: "restaurant", lat: 40, lng: 49, address: "A", createdAt: new Date(),
      });
    });
  });

  test("sahib təsdiqlənmiş təklifə freeCampaignHold GERİ YAZA bilmir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", "cq-offer"), { freeCampaignHold: true }));
  });

  test("sahib freeCampaignHold-u silə də bilmir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", "cq-offer"), { freeCampaignHold: false }));
  });
});

describe("A5-M2 — başlıq ölçü həddi", () => {
  test("hədsiz uzun tədbir başlığı rədd edilir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertFails(
      setDoc(doc(db, "venueEvents", "cq-longtitle"), {
        venueId: APPROVED, title: "a".repeat(200), description: "T", status: "pending",
        startAt: new Date(Date.now() + 3600_000), endAt: new Date(Date.now() + 7200_000),
        category: "concert", createdAt: new Date(),
      }),
    );
  });

  test("normal başlıq keçir", async () => {
    const db = env.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      setDoc(doc(db, "venueEvents", "cq-oktitle"), {
        venueId: APPROVED, title: "Normal başlıq", description: "T", status: "pending",
        startAt: new Date(Date.now() + 3600_000), endAt: new Date(Date.now() + 7200_000),
        category: "concert", createdAt: new Date(),
      }),
    );
  });
});
