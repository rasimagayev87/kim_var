// P0 / H-9 (REGRESSION) — `users/{uid}/private/data`-nın sahə-səviyyəli
// kilidi.
//
// Düzəliş Prompt 4 həssas sahələri valideyn sənəddən bura köçürdü, amma
// buradakı qayda `allow read, write: if uid == userId` idi — yəni
// valideyn sənəddəki `touchesLockedUserFields()` kilidi sahələrlə
// BİRLİKDƏ KÖÇMƏDİ. Ən ağır nəticəsi: `completeOnboarding`-in 18+
// qapısı bir `set(..., {birthDate}, merge:true)` ilə ləğv edilə bilirdi.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

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

const U = "p0h9-user";
const OTHER = "p0h9-other";
const privatePath = (uid: string) => ["users", uid, "private", "data"] as const;

describe("P0 / H-9 — private/data server-only sahələri", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", U), userFixture(U));
      await setDoc(doc(fs, "users", OTHER), userFixture(OTHER));
      // Onboarding-in yazdığı ilkin vəziyyət (Admin SDK, qaydaları keçir).
      await setDoc(doc(fs, ...privatePath(U)), {
        birthDate: new Date("1995-06-15"),
        email: "real@example.com",
        phoneNumber: "+994500000000",
        loginProvider: "email",
        consent: { termsAccepted: true, termsVersion: "1.0", privacyVersion: "1.0" },
        fcmTokens: ["tok-real"],
        knownDeviceSignatures: ["sig-real"],
        blockedByUsers: [OTHER],
        lat: 40.4,
        lng: 49.8,
        ghostModeEnabled: false,
      });
    });
  });

  // --- ƏSAS REQRESSİYA: yaş qapısı ---
  test("birthDate dəyişdirilə BİLMİR (18+ qapısının dəyişməzliyi)", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, ...privatePath(U)), { birthDate: new Date("2012-01-01") }));
  });

  test("birthDate merge-set ilə də dəyişdirilə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, ...privatePath(U)), { birthDate: new Date("2012-01-01") }, { merge: true }),
    );
  });

  test("birthDate icazəli bir sahə ilə BİRLİKDƏ göndərilsə də bütün yazı rədd edilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, ...privatePath(U)), { lat: 41.0, birthDate: new Date("2012-01-01") }, { merge: true }),
    );
  });

  // --- digər server-only sahələr ---
  for (const [field, value] of [
    ["email", "spoofed@example.com"],
    ["phoneNumber", "+994999999999"],
    ["loginProvider", "google"],
    ["consent", { termsAccepted: true, termsVersion: "99.0", privacyVersion: "99.0" }],
    ["knownDeviceSignatures", ["sig-attacker"]],
    ["blockedByUsers", []],
  ] as const) {
    test(`${field} client tərəfindən dəyişdirilə BİLMİR`, async () => {
      const db = testEnv.authenticatedContext(U).firestore();
      await assertFails(setDoc(doc(db, ...privatePath(U)), { [field]: value }, { merge: true }));
    });
  }

  test("fcmTokens client tərəfindən dəyişdirilə BİLMİR (başqasının token-i əlavə edilə bilməz)", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(
      setDoc(doc(db, ...privatePath(U)), { fcmTokens: ["tok-real", "victim-device-token"] }, { merge: true }),
    );
  });

  // --- icazəli sahələr pozulmamalıdır ---
  test("lat/lng yazıla bilir (lokasiya axını pozulmur)", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(db, ...privatePath(U)), { lat: 41.1, lng: 47.2 }, { merge: true }));
  });

  test("məxfilik/bildiriş ayarları yazıla bilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(
      setDoc(
        doc(db, ...privatePath(U)),
        {
          ghostModeEnabled: true,
          visibilityRadiusMode: "distance",
          visibilityRadiusKm: 5,
          notificationPreferences: { marketing: false },
          showReadReceipts: false,
        },
        { merge: true },
      ),
    );
  });

  test("activeCheckinVenueId və activeChatId yazıla bilir (check-in/çat axınları)", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(
      setDoc(doc(db, ...privatePath(U)), { activeCheckinVenueId: "venue1", activeChatId: "chat1" }, { merge: true }),
    );
  });

  test("telemetriya sahələri yazıla bilir", async () => {
    const db = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(
      setDoc(
        doc(db, ...privatePath(U)),
        { appVersion: "1.0.0", buildNumber: "10", platform: "android", osVersion: "14" },
        { merge: true },
      ),
    );
  });

  // --- ilk yaradılış (sənəd hələ mövcud deyil) ---
  test("sənəd hələ yoxdursa icazəli sahələrlə YARADILA bilir (onboarding-dən əvvəlki yazıcılar)", async () => {
    const fresh = "p0h9-fresh";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", fresh), userFixture(fresh));
    });
    const db = testEnv.authenticatedContext(fresh).firestore();
    await assertSucceeds(setDoc(doc(db, ...privatePath(fresh)), { lat: 40.0, lng: 49.0 }));
  });

  test("sənəd hələ yoxdursa server-only sahə ilə YARADILA BİLMİR", async () => {
    const fresh2 = "p0h9-fresh2";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", fresh2), userFixture(fresh2));
    });
    const db = testEnv.authenticatedContext(fresh2).firestore();
    await assertFails(setDoc(doc(db, ...privatePath(fresh2)), { birthDate: new Date("2012-01-01") }));
  });

  // --- oxu tərəfi dəyişməyib ---
  test("sahib öz private/data-sını oxuya bilir, başqası BİLMİR", async () => {
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(U).firestore(), ...privatePath(U))));
    await assertFails(getDoc(doc(testEnv.authenticatedContext(OTHER).firestore(), ...privatePath(U))));
  });

  test("valideyn users/{uid} sənədinə birthDate yazmaq da rədd edilir (merge fallback yolu)", async () => {
    // `withPrivateData` iki sənədi `{...public, ...private}` kimi
    // birləşdirir — private-da `birthDate` yoxdursa, PUBLIC-dəki dəyər
    // istifadə olunur. Ona görə hər iki yer kilidli olmalıdır; təkcə
    // biri kifayət etmir.
    const db = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(db, "users", U), { birthDate: new Date("2012-01-01") }));
  });
});

describe("P0 / H-1 (b) — nearbyProbes server-only kolleksiyası", () => {
  test("client oxuya da, yaza da bilmir", async () => {
    // Dinamik `import()` FƏRQLİ modul nüsxəsi qaytarır və Firestore
    // "Type does not match the expected instance" xətası verir —
    // yuxarıdakı top-level idxal istifadə olunur.
    const db = testEnv.authenticatedContext("p0h1-user").firestore();
    await assertFails(getDoc(doc(db, "nearbyProbes", "p0h1-user")));
    await assertFails(setDoc(doc(db, "nearbyProbes", "p0h1-user"), { lat: 0, lng: 0, at: 0 }));
  });
});
