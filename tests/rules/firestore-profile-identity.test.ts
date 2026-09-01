// «Kilidləndi, amma açarı verilmədi» — kimlik sahələrinin qayda tərəfi.
//
// İki şeyi eyni anda təsbit edir:
//
//  1. `username`/`firstName`/`lastName`/`nameLower` və kuldaun ştampları
//     KLİENTDƏN yazıla bilmir. Kuldaunlar `updateProfileDetails`-dədir;
//     klient yaza bilsəydi, kuldaun sadəcə tövsiyə olardı.
//
//  2. Bunlardan asılı OLMAYAN sahələr (bio, country, photoUrl) hələ də
//     sərbəst yazılır. Bu ikinci hissə əsl regressiya hasarıdır: bu
//     düzəlişin özü kilid siyahısını genişləndirdiyi üçün, siyahının
//     həddindən artıq genişlənməsi məhz yenidən yaratdığımız səhvdir.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
before(async () => { testEnv = await createTestEnv(); });
after(async () => { await testEnv.cleanup(); });

const U = "identity-user";
const privatePath = (uid: string) => ["users", uid, "private", "data"] as const;

describe("Profil kimlik sahələri — klient yaza bilməz", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, "users", U), {
        ...userFixture(U),
        username: "identityuser",
        firstName: "Əli",
        lastName: "Məmmədov",
        nameLower: "əli məmmədov",
        bio: "köhnə",
      });
      await setDoc(doc(fs, "usernames", "identityuser"), { uid: U });
      await setDoc(doc(fs, ...privatePath(U)), {
        birthDate: new Date("1995-06-15"),
        phoneNumber: "+994501112233",
        city: "Baku",
      });
    });
  });

  const locked: Array<[string, Record<string, unknown>]> = [
    ["username", { username: "yenihandle" }],
    ["firstName", { firstName: "Yeni" }],
    ["lastName", { lastName: "Soyad" }],
    ["nameLower", { nameLower: "yeni soyad" }],
    ["usernameChangedAt", { usernameChangedAt: serverTimestamp() }],
    ["nameChangedAt", { nameChangedAt: serverTimestamp() }],
  ];
  for (const [field, payload] of locked) {
    test(`sahib \`${field}\` yaza bilmir`, async () => {
      const fs = testEnv.authenticatedContext(U).firestore();
      await assertFails(setDoc(doc(fs, "users", U), payload, { merge: true }));
    });
  }

  test("sahib `birthDateChangedAt` yaza bilmir", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(fs, ...privatePath(U)), { birthDateChangedAt: serverTimestamp() }, { merge: true }),
    );
  });

  test("sahib `phoneNumber` yaza bilmir — yalnız callable dəyişir", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(fs, ...privatePath(U)), { phoneNumber: "+994505556677" }, { merge: true }),
    );
  });

  test("`usernames` rezervasiyası ilə birlikdə də keçmir", async () => {
    // Köhnə axın məhz bunu edirdi: əvvəlcə rezervasiya, sonra sənəd.
    // Rezervasiya hələ də yaradıla bilər (deep-link üçün açıqdır), amma
    // `users.username` artıq bağlıdır — yəni yarımçıq vəziyyət qalmır.
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(fs, "usernames", "yenihandle2"), { uid: U, createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(fs, "users", U), { username: "yenihandle2" }, { merge: true }));
  });
});

describe("Kilid həddindən artıq genişlənməyib", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", U), { ...userFixture(U), bio: "köhnə" });
      await setDoc(doc(ctx.firestore(), ...privatePath(U)), { city: "Baku" });
    });
  });

  test("bio hələ də sərbəst yazılır", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(fs, "users", U), { bio: "yeni" }, { merge: true }));
  });

  test("country hələ də sərbəst yazılır", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(fs, "users", U), { country: "Azərbaycan" }, { merge: true }));
  });

  test("private/data-da city və gender hələ də sərbəst yazılır", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(
      setDoc(doc(fs, ...privatePath(U)), { city: "Gəncə", gender: "male" }, { merge: true }),
    );
  });
});
