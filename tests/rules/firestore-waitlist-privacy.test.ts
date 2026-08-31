// Növbə girişində telefon nömrəsi var. Kim oxuya bilir?
//
// Girişdə `phoneNumber`, `partySize`, `note`, `userId` saxlanılır —
// məkan sahibi müştərini çağıra bilsin deyə. Sual budur ki, eyni
// növbədə duran BAŞQA istifadəçilər onu görürmü.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, query, setDoc, where } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
const OWNER = "wl-owner";
const ALICE = "wl-alice";   // növbədə
const BOB = "wl-bob";       // növbədə
const OUTSIDER = "wl-outsider";
const VENUE = "wl-venue";

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const uid of [OWNER, ALICE, BOB, OUTSIDER]) {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    }
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, { category: "restaurant" }));
    for (const [id, uid, phone] of [["e-alice", ALICE, "+994501111111"], ["e-bob", BOB, "+994502222222"]]) {
      await setDoc(doc(fs, "venues", VENUE, "waitlist", id), {
        userId: uid, phoneNumber: phone, partySize: 2, status: "waiting", joinedAt: new Date(), queuePosition: 1,
      });
    }
  });
});
after(async () => { await testEnv.cleanup(); });

const entries = (db: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"] extends never ? never : any) =>
  collection(db, "venues", VENUE, "waitlist");

describe("növbə — telefon nömrəsini kim görür", () => {
  test("məkan sahibi bütün siyahını oxuyur — müştərini çağırmalıdır", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(getDocs(entries(db)));
  });

  test("istifadəçi ÖZ girişini oxuyur", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(getDoc(doc(db, "venues", VENUE, "waitlist", "e-alice")));
    await assertSucceeds(getDocs(query(entries(db), where("userId", "==", ALICE))));
  });

  test("NÖVBƏDƏKİ BAŞQA İSTİFADƏÇİ digərinin girişini oxuya BİLMİR", async () => {
    // Əsas sual budur: Alice növbədədir, Bob-un nömrəsini görürmü.
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "waitlist", "e-bob")));
  });

  test("növbədəki istifadəçi bütün siyahını siyahılaya BİLMİR", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDocs(entries(db)));
  });

  test("başqasının uid-i ilə süzülmüş sorğu da keçmir", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDocs(query(entries(db), where("userId", "==", BOB))));
  });

  test("kənar istifadəçi nə siyahını, nə girişi oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(OUTSIDER).firestore();
    await assertFails(getDocs(entries(db)));
    await assertFails(getDoc(doc(db, "venues", VENUE, "waitlist", "e-alice")));
  });

  test("növbəyə client birbaşa yaza bilmir — yalnız joinWaitlist callable", async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, "venues", VENUE, "waitlist", "e-forged"), {
        userId: ALICE, phoneNumber: "+994503333333", partySize: 1, status: "waiting", joinedAt: new Date(),
      }),
    );
  });
});
