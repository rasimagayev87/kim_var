// Məkandan asılı client yazılarının məkanın/təklifin mövcudluğunu
// yoxlaması.
//
// Kontekst: PinBox YARATMA onsuz da məkan sahibliyinə bağlıdır
// (`pinboxes` create qaydası, K-9) — problem bağlılığın YALNIZ yaratma
// anında yoxlanılması idi. Ondan sonra məkan silinə, rədd edilə və ya
// abunə borcuna görə dayandırıla bilər; asılı sənədlər isə öz
// statuslarını saxlayır və kəşfdə qalır.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (fs: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

const USER = "vd-user";
const OWNER = "vd-owner";
const LIVE_VENUE = "vd-venue-live";
const GONE_VENUE = "vd-venue-gone";

describe("offers/{id}/redemptions — təklif mövcud və approved olmalıdır", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", USER), userFixture(USER));
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "venues", LIVE_VENUE), venueFixture(OWNER));
      await setDoc(doc(fs, "offers", "vd-offer-ok"), { ownerId: OWNER, venueId: LIVE_VENUE, status: "approved" });
      await setDoc(doc(fs, "offers", "vd-offer-rejected"), { ownerId: OWNER, venueId: LIVE_VENUE, status: "rejected" });
      await setDoc(doc(fs, "offers", "vd-offer-pending"), { ownerId: OWNER, venueId: LIVE_VENUE, status: "pending" });
    });
  });

  test("approved təklif aktivləşdirilə bilir", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertSucceeds(setDoc(doc(db, "offers", "vd-offer-ok", "redemptions", USER), { at: new Date() }));
  });

  test("rədd edilmiş təklif aktivləşdirilə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertFails(setDoc(doc(db, "offers", "vd-offer-rejected", "redemptions", USER), { at: new Date() }));
  });

  test("moderasiyada olan təklif aktivləşdirilə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertFails(setDoc(doc(db, "offers", "vd-offer-pending", "redemptions", USER), { at: new Date() }));
  });

  test("mövcud olmayan təklif aktivləşdirilə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertFails(setDoc(doc(db, "offers", "vd-offer-yoxdur", "redemptions", USER), { at: new Date() }));
  });

  test("başqasının adına aktivləşdirmə hələ də rədd edilir (reqressiya yoxdur)", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertFails(setDoc(doc(db, "offers", "vd-offer-ok", "redemptions", OWNER), { at: new Date() }));
  });
});

describe("venues/{id}/likes — məkan mövcud olmalıdır", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", USER), userFixture(USER));
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "venues", LIVE_VENUE), venueFixture(OWNER));
    });
  });

  test("mövcud məkan bəyənilə bilir", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertSucceeds(setDoc(doc(db, "venues", LIVE_VENUE, "likes", USER), { at: new Date() }));
  });

  test("silinmiş məkan bəyənilə BİLMİR (orphan sayğac yazısı yaranmır)", async () => {
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertFails(setDoc(doc(db, "venues", GONE_VENUE, "likes", USER), { at: new Date() }));
  });

  test("silinmiş məkandan bəyənməni GERİ GÖTÜRMƏK icazəlidir", async () => {
    // Məkan sonradan silinibsə, istifadəçi öz köhnə bəyənməsini
    // təmizləyə bilməlidir — silmə mövcudluqdan asılı deyil.
    await seed(async (fs) => {
      await setDoc(doc(fs, "venues", GONE_VENUE, "likes", USER), { at: new Date() });
    });
    const db = testEnv.authenticatedContext(USER).firestore();
    await assertSucceeds(deleteDoc(doc(db, "venues", GONE_VENUE, "likes", USER)));
  });
});
