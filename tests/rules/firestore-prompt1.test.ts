// Düzəliş Prompt 12 — Prompt 1 (yaş qapısı) davranış testləri.
// Əhatə: firestore.rules `match /users/{userId}` bloku — `allow create:
// if false`, `touchesLockedUserFields()`.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, Timestamp } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

// P0 / H-5 — `photoUrl` artıq yalnız öz Storage bucket-imizə işarə
// edə bilər (dəyişdirildiyi yazılarda). Bu fixture əvvəllər
// "https://example.com/p.jpg" idi.
const OWN_STORAGE_URL =
  "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/x%2Fy.jpg?alt=media&token=t";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

describe("Prompt 1 — users/{uid} create həmişə rədd edilir (bənd 1)", () => {
  test("sahibi belə users sənədi birbaşa yarada bilməz (create: if false)", async () => {
    const uid = "p1-create-owner";
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      setDoc(doc(db, "users", uid), userFixture(uid, { birthDate: Timestamp.now() })),
    );
  });
});

describe("Prompt 1 — birthDate kilidlidir (bənd 2-3)", () => {
  test("mövcud birthDate dəyərinin dəyişdirilməsi rədd edilir", async () => {
    const uid = "p1-birthdate-change";
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", uid), userFixture(uid, { birthDate: Timestamp.fromDate(new Date("2000-01-01")) }));
    });
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      updateDoc(doc(db, "users", uid), { birthDate: Timestamp.fromDate(new Date("2001-01-01")) }),
    );
  });

  test("BİLİNƏN YAN TƏSİR — birthDate sahəsi olmayan sənədə birthDate əlavə etmək də rədd edilir", async () => {
    const uid = "p1-birthdate-add";
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const { birthDate: _omit, ...withoutBirthDate } = userFixture(uid);
      await setDoc(doc(ctx.firestore(), "users", uid), withoutBirthDate);
    });
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      updateDoc(doc(db, "users", uid), { birthDate: Timestamp.now() }),
    );
  });
});

describe("Prompt 1 — kilidsiz sahələr sərbəst qalır (bənd 4)", () => {
  test("bio, city və photoUrl-un eyni yazıda yenilənməsi keçir", async () => {
    const uid = "p1-other-fields";
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", uid), userFixture(uid, { birthDate: Timestamp.now() }));
    });
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "users", uid), { bio: "Yeni bio", city: "Bakı", photoUrl: OWN_STORAGE_URL }),
    );
  });
});

describe("Prompt 1 — grant-of-privilege sahələr kilidlidir (bənd 5)", () => {
  const setupOwner = async (uid: string) => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", uid), userFixture(uid, { birthDate: Timestamp.now() }));
    });
    return testEnv.authenticatedContext(uid).firestore();
  };

  test("premium sahəsinin sahib tərəfindən dəyişdirilməsi rədd edilir", async () => {
    const uid = "p1-lock-premium";
    const db = await setupOwner(uid);
    await assertFails(updateDoc(doc(db, "users", uid), { premium: true }));
  });

  test("identityVerified sahəsinin sahib tərəfindən dəyişdirilməsi rədd edilir", async () => {
    const uid = "p1-lock-identity";
    const db = await setupOwner(uid);
    await assertFails(updateDoc(doc(db, "users", uid), { identityVerified: true }));
  });

  test("premiumExpiresAt sahəsinin sahib tərəfindən dəyişdirilməsi rədd edilir", async () => {
    const uid = "p1-lock-premium-expires";
    const db = await setupOwner(uid);
    await assertFails(updateDoc(doc(db, "users", uid), { premiumExpiresAt: Timestamp.now() }));
  });
});

// Say: 7 test (promptun 5 bəndinin tam əhatəsi — bənd 5 dəqiqlik üçün
// 3 ayrı testə açılıb, bənd 4 tək testdə birləşdirilib, mətndəki
// qruplaşdırmaya uyğun).
