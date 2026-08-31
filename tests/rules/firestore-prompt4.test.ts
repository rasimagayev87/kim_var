// Düzəliş Prompt 12 — Prompt 4 (`users` PII ayrımı, K-1/K-4/RT-25) davranış
// testləri. Əhatə: `users/{uid}` publik sahələrin kross-oxusu (dəyişməz
// qalmalıdır), `users/{uid}/private/data`-nın sahib-yalnız qaydası,
// `users` kolleksiyası üzərində `list` qadağası (RT-25), və
// `activeCheckins` xam alt-kolleksiyasının daraldılmış oxusu (K-4).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (db: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

describe("Prompt 4 — users/{uid} publik sahələr (dəyişməz qalmalıdır)", () => {
  const owner = "p4-public-owner";
  const stranger = "p4-public-stranger";

  before(async () => {
    await seed((db) => setDoc(doc(db, "users", owner), userFixture(owner, { firstName: "Aysel" })));
  });

  test("başqa istifadəçi publik sahəni (get, tək sənəd) oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(stranger).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "users", owner)));
    if (snap.data()?.firstName !== "Aysel") throw new Error("Public field not readable as expected");
  });
});

describe("Prompt 4 — RT-25: users kolleksiyası üzərində list qadağandır", () => {
  const uid = "p4-list-denied";

  before(async () => {
    await seed((db) => setDoc(doc(db, "users", uid), userFixture(uid)));
  });

  test("hər hansı where() sorğusu ilə users siyahılamaq rədd edilir", async () => {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDocs(query(collection(db, "users"), where("online", "==", true))));
  });

  test("eyni uid öz sənədini get() ilə oxuya bilir (list qadağası get-i əhatə etmir)", async () => {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, "users", uid)));
  });
});

describe("Prompt 4 — users/{uid}/private/data yalnız sahibə açıqdır", () => {
  const owner = "p4-private-owner";
  const stranger = "p4-private-stranger";

  before(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "users", owner), userFixture(owner));
      await setDoc(doc(db, "users", owner, "private", "data"), {
        email: "owner@example.com",
        phoneNumber: "+994500000000",
        gender: "Qadın",
      });
    });
  });

  test("sahib öz private/data sənədini oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "users", owner, "private", "data")));
    if (snap.data()?.email !== "owner@example.com") throw new Error("Owner should see own private data");
  });

  test("başqa istifadəçi private/data sənədini oxuya bilmir", async () => {
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertFails(getDoc(doc(db, "users", owner, "private", "data")));
  });

  test("sahib öz private/data sənədinə yaza bilir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertSucceeds(updateDoc(doc(db, "users", owner, "private", "data"), { gender: "Kişi" }));
  });

  test("başqa istifadəçi sahibin private/data sənədinə yaza bilmir", async () => {
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertFails(updateDoc(doc(db, "users", owner, "private", "data"), { gender: "Kişi" }));
  });

  test("başqa istifadəçi sahibin private altında yeni sənəd yarada bilmir", async () => {
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertFails(setDoc(doc(db, "users", owner, "private", "other"), { hack: true }));
  });
});

describe("Prompt 4 — K-4: activeCheckins xam alt-kolleksiyası daraldılıb", () => {
  const venueOwner = "p4-checkin-venue-owner";
  const checkedInUser = "p4-checkin-user";
  const outsider = "p4-checkin-outsider";
  const venueId = "p4-checkin-venue";

  before(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "users", venueOwner), userFixture(venueOwner));
      await setDoc(doc(db, "users", checkedInUser), userFixture(checkedInUser));
      await setDoc(doc(db, "users", outsider), userFixture(outsider));
      await setDoc(doc(db, "venues", venueId), venueFixture(venueOwner, { activeCheckinCount: 1 }));
      await setDoc(doc(db, "venues", venueId, "activeCheckins", checkedInUser), { createdAt: new Date() });
    });
  });

  test("check-in edən istifadəçi öz sənədini oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(checkedInUser).firestore();
    await assertSucceeds(getDoc(doc(db, "venues", venueId, "activeCheckins", checkedInUser)));
  });

  test("məkanın sahibi ARTIQ check-in sənədini oxuya BİLMİR", async () => {
    // 2026-08-31-də tərsinə çevrildi. Prompt 4 / K-4 bu qaydanı «hər
    // qeydiyyatlı istifadəçi»dən «sahib + check-in edən»ə daraltmışdı
    // və bu test həmin aralıq vəziyyəti qeydə alırdı. İndi yalnız
    // check-in edənin özü qalır: xam siyahı konkret anda konkret
    // yerdə olan insanların siyahısıdır, sahibin isə ondan alacağı
    // heç nə yoxdur ki, `activeCheckinCount` aqreqatı onsuz da
    // verməsin. Tam əsaslandırma `firestore.rules`-dadır,
    // əhatəli testlər `firestore-checkin.test.ts`-də.
    const db = testEnv.authenticatedContext(venueOwner).firestore();
    await assertFails(getDoc(doc(db, "venues", venueId, "activeCheckins", checkedInUser)));
  });

  test("kənar istifadəçi başqasının check-in sənədini oxuya bilmir", async () => {
    const db = testEnv.authenticatedContext(outsider).firestore();
    await assertFails(getDoc(doc(db, "venues", venueId, "activeCheckins", checkedInUser)));
  });

  test("kənar istifadəçi activeCheckins-i siyahılaya bilmir", async () => {
    const db = testEnv.authenticatedContext(outsider).firestore();
    await assertFails(getDocs(collection(db, "venues", venueId, "activeCheckins")));
  });

  test("activeCheckinCount sayğacı hər imzalanmış istifadəçiyə oxunur (venue sənədinin bir hissəsi)", async () => {
    const db = testEnv.authenticatedContext(outsider).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "venues", venueId)));
    if (snap.data()?.activeCheckinCount !== 1) throw new Error("activeCheckinCount should be readable");
  });

  test("client activeCheckinCount-u birbaşa dəyişə bilmir (yalnız Cloud Function)", async () => {
    const db = testEnv.authenticatedContext(venueOwner).firestore();
    await assertFails(updateDoc(doc(db, "venues", venueId), { activeCheckinCount: 999 }));
  });
});

// Say: 14 test (publik sahə 1, RT-25 list 2, private/data 5, activeCheckins 6).
