// P0 — sinif-səviyyəli axtarışın (c) naxışı: "yeni sahə blocklist-ə
// salınmayıb". Prompt 6 / INFRA-5 `offers`/`pinboxes`-ə bütün MƏZMUN
// sahələrini əlavə etdi, amma listing-in KİMLİK və YER sahələrini
// kənarda qoydu; `venues`-də isə `name` kilidli, onun axtarış açarı
// `nameLower` isə açıq idi.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
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

const OWNER = "p0bl-owner";
const RIVAL = "p0bl-rival";
const VENUE = "p0bl-venue";
const RIVAL_VENUE = "p0bl-rival-venue";
const OFFER = "p0bl-offer";
const PINBOX = "p0bl-pinbox";

describe("P0 / C-b — offers: kimlik və yer sahələri kilidlidir", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "users", RIVAL), userFixture(RIVAL));
      await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER));
      await setDoc(doc(fs, "venues", RIVAL_VENUE), venueFixture(RIVAL));
      await setDoc(doc(fs, "offers", OFFER), {
        ownerId: OWNER,
        venueId: VENUE,
        venueName: "Mənim məkanım",
        status: "approved",
        title: "Təsdiqlənmiş təklif",
        lat: 40.4,
        lng: 49.8,
        address: "Bakı",
      });
    });
  });

  test("təsdiqlənmiş təklifin venueId-si BAŞQASININ məkanına yönəldilə bilmir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", OFFER), { venueId: RIVAL_VENUE }));
  });

  test("təsdiqlənmiş təklif coğrafi olaraq KÖÇÜRÜLƏ bilmir (lat/lng/position)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", OFFER), { lat: 41.7, lng: 44.8 }));
    await assertFails(
      updateDoc(doc(db, "offers", OFFER), { position: { geohash: "xxxx", geopoint: null } }),
    );
  });

  test("venueName/venuePhotoUrl saxtalaşdırıla bilmir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", OFFER), { venueName: "Rəqibin məkanı" }));
    await assertFails(updateDoc(doc(db, "offers", OFFER), { venuePhotoUrl: "https://x/y.jpg" }));
  });

  test("hədəfləmə sahələri (targetUserIds/personalMessage) kilidlidir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", OFFER), { targetUserIds: ["p0bl-rival"] }));
  });

  test("əvvəldən kilidli məzmun sahələri hələ də kilidlidir (reqressiya yoxdur)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "offers", OFFER), { title: "Dəyişdirilmiş" }));
    await assertFails(updateDoc(doc(db, "offers", OFFER), { status: "approved", boostedUntil: new Date() }));
  });
});

describe("P0 / C-c — pinboxes: kateqoriya, yer və stockTotal kilidlidir", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER));
      await setDoc(doc(fs, "pinboxes", PINBOX), {
        ownerId: OWNER,
        venueId: VENUE,
        category: "restaurant",
        status: "active",
        title: "Qutu",
        stockTotal: 10,
        stockRemaining: 4,
        pinboxPrice: 12,
        originalPrice: 20,
        lat: 40.4,
        lng: 49.8,
      });
    });
  });

  test("təsdiqdən sonra kateqoriya dəyişdirilə bilmir (isOfferOnlyCategory yalnız create-də yoxlanır)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", PINBOX), { category: "wineHouse" }));
  });

  test("stockTotal dəyişdirilə bilmir (stockRemaining ilə uyğunsuzluq)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", PINBOX), { stockTotal: 999 }));
  });

  test("PinBox coğrafi olaraq köçürülə bilmir", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", PINBOX), { lat: 41.7, lng: 44.8 }));
  });

  test("qiymət sahələri hələ də kilidlidir (reqressiya yoxdur)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", PINBOX), { pinboxPrice: 1 }));
    await assertFails(updateDoc(doc(db, "pinboxes", PINBOX), { stockRemaining: 999 }));
  });
});

describe("P0 / C-d — venues: nameLower kilidlidir", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", OWNER), userFixture(OWNER));
      await setDoc(doc(fs, "venues", VENUE), {
        ...venueFixture(OWNER),
        name: "Təsdiqlənmiş Ad",
        nameLower: "təsdiqlənmiş ad",
      });
    });
  });

  test("nameLower ayrıca dəyişdirilə bilmir (axtarış zəhərlənməsi)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", VENUE), { nameLower: "pulsuz pizza endirim" }));
  });

  test("name onsuz da kilidli idi (reqressiya yoxdur)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(updateDoc(doc(db, "venues", VENUE), { name: "Başqa Ad" }));
  });

  test("icazəli sahibkar yazıları hələ işləyir (availableSeats, elan kartı)", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "venues", VENUE), { availableSeats: 12, seatsUpdatedAt: new Date() }),
    );
    await assertSucceeds(updateDoc(doc(db, "venues", VENUE), { firstPaymentAnnouncementPending: false }));
  });
});
