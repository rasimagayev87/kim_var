// Könüllü check-in — kim nəyi oxuya bilər.
//
// Xam `activeCheckins` siyahısı konkret anda konkret yerdə olan
// İNSANLARIN siyahısıdır. Say statistikadır; siyahı izləmədir, və
// istifadəçi sayğac üçün düymə basanda buna razılıq vermir. Məkan
// sahibinin girişi də bağlıdır — aqreqat (`activeCheckinCount`) hər
// ekranın onsuz da oxuduğu dəyərdir.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, getDocs, collection, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
const OWNER = "ci-owner";
const VISITOR = "ci-visitor";
const OTHER = "ci-other";
const BANNED = "ci-banned";
const VENUE = "ci-venue";

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const uid of [OWNER, VISITOR, OTHER, BANNED]) {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    }
    await setDoc(doc(fs, "bannedUsers", BANNED), { bannedAt: new Date() });
    await setDoc(doc(fs, "venues", VENUE), venueFixture(OWNER, { category: "restaurant" }));
    await setDoc(doc(fs, "venues", VENUE, "activeCheckins", VISITOR), { createdAt: new Date() });
  });
});
after(async () => { await testEnv.cleanup(); });

describe("check-in — xam siyahının oxunması", () => {
  test("check-in edən öz sənədini oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(VISITOR).firestore();
    await assertSucceeds(getDoc(doc(db, "venues", VENUE, "activeCheckins", VISITOR)));
  });

  test("MƏKAN SAHİBİ xam siyahını oxuya BİLMİR", async () => {
    // Əvvəllər bilirdi. Sahibin ehtiyacı aqreqatla tam ödənilir.
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(getDocs(collection(db, "venues", VENUE, "activeCheckins")));
  });

  test("məkan sahibi konkret şəxsin sənədini də oxuya BİLMİR", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(getDoc(doc(db, "venues", VENUE, "activeCheckins", VISITOR)));
  });

  test("kənar istifadəçi nə siyahını, nə sənədi oxuya bilir", async () => {
    const db = testEnv.authenticatedContext(OTHER).firestore();
    await assertFails(getDocs(collection(db, "venues", VENUE, "activeCheckins")));
    await assertFails(getDoc(doc(db, "venues", VENUE, "activeCheckins", VISITOR)));
  });

  test("aqreqat say hamıya açıqdır — ekranların oxuduğu budur", async () => {
    for (const uid of [OWNER, OTHER, VISITOR]) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(getDoc(doc(db, "venues", VENUE)));
    }
  });
});

describe("check-in — yazma", () => {
  test("aktiv istifadəçi öz check-in-ini yarada bilir", async () => {
    const db = testEnv.authenticatedContext(OTHER).firestore();
    await assertSucceeds(setDoc(doc(db, "venues", VENUE, "activeCheckins", OTHER), { createdAt: new Date() }));
  });

  test("başqasının adına check-in edə bilmir", async () => {
    const db = testEnv.authenticatedContext(OTHER).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "activeCheckins", VISITOR), { createdAt: new Date() }));
  });

  test("banlanmış hesab check-in edə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "activeCheckins", BANNED), { createdAt: new Date() }));
  });

  test("banlanmış hesab check-in halında ÇIXA bilir", async () => {
    // Qəsdən: ban zamanı içəridə olan adam məkanın canlı sayında
    // ilişib qalmamalıdır.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "activeCheckins", BANNED), { createdAt: new Date() });
    });
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertSucceeds(deleteDoc(doc(db, "venues", VENUE, "activeCheckins", BANNED)));
  });

  test("başqasının check-in-ini silə bilmir", async () => {
    const db = testEnv.authenticatedContext(OTHER).firestore();
    await assertFails(deleteDoc(doc(db, "venues", VENUE, "activeCheckins", VISITOR)));
  });
});

describe("sayğac ayrımı — xam say client-dən gizlidir", () => {
  test("private/counters heç kimə açıq deyil — sahibə də", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "private", "counters"), { activeCheckinCount: 3 });
    });
    for (const uid of [OWNER, VISITOR, OTHER]) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(getDoc(doc(db, "venues", VENUE, "private", "counters")));
    }
  });

  test("private/counters-ə yazmaq da olmaz", async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertFails(setDoc(doc(db, "venues", VENUE, "private", "counters"), { activeCheckinCount: 999 }));
  });

  test("audienceHistory bağlıdır (Audit 3 / A3-M2)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE, "audienceHistory", "h1"),
        { count: 1, hour: 12, timestamp: new Date() });
    });
    for (const uid of [OWNER, VISITOR, OTHER]) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(getDocs(collection(db, "venues", VENUE, "audienceHistory")));
      await assertFails(getDoc(doc(db, "venues", VENUE, "audienceHistory", "h1")));
    }
  });

  test("məkan sənədindəki göstəriş sahələri oxunur", async () => {
    // Client-in oxuduğu yeganə saylar bunlardır və hər ikisi
    // serverdə həddlənib.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "venues", VENUE),
        { ...venueFixture(OWNER, { category: "restaurant" }), visibleCheckinCount: 0, currentAudienceCount: 7 },
      );
    });
    const db = testEnv.authenticatedContext(OTHER).firestore();
    await assertSucceeds(getDoc(doc(db, "venues", VENUE)));
  });
});
