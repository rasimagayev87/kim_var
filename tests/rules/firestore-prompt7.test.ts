// Düzəliş Prompt 7 — Store IAP: Qəbz Doğrulaması və VIP Bağlılığı.
// Bu promptun əsas məntiqi (PAY-25 — `claimIapSubscriptionOwnership`,
// H #196 — sandbox rəddi) Cloud Function DAXİLİ məntiqdir və Firestore
// emulator rules testləri ilə sınana bilməz (bax Prompt 6-nın eyni
// qərarı). Burada YALNIZ rules-səviyyəli hissə sınanır:
//   - `iapSubscriptions/{key}` — client nə oxuya, nə yaza bilmir
//     (mövcud `allow read, write: if false`, hələ test edilməyib).
//   - `config/iapTesters` — client oxuya bilir (mövcud `config/{docId}`
//     qaydası), yaza bilmir.
//   - `users/{uid}.premium`/`premiumExpiresAt` kilidi ARTIQ
//     `firestore-prompt1.test.ts:75-91`-də test edilib —
//     TƏKRARLANMIR, yalnız qeyd olunur.
import { after, before, describe, test } from "node:test";
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

describe("PAY-25 — iapSubscriptions/{key} tam client-dən bağlıdır", () => {
  test("sahib olduğu iddia edilən istifadəçi belə öz sənədini oxuya bilmir", async () => {
    const uid = "p7-iap-owner-a";
    const key = "p7-original-transaction-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
      await setDoc(doc(fs, "iapSubscriptions", key), { uid, platform: "ios", productId: "peakpin_vip_monthly" });
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDoc(doc(db, "iapSubscriptions", key)));
  });

  test("istifadəçi öz uid-i ilə yeni sənəd yaratmağa çalışır — rədd edilir (yalnız Admin SDK yaza bilər)", async () => {
    const uid = "p7-iap-owner-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      setDoc(doc(db, "iapSubscriptions", "p7-fake-transaction"), {
        uid,
        platform: "android",
        productId: "peakpin_vip_yearly",
      }),
    );
  });

  test("istifadəçi BAŞQA uid-in sənədinin `uid` sahəsini öz üzərinə yazmağa çalışır — rədd edilir (PAY-25-in özünün simulyasiyası, rules səviyyəsində)", async () => {
    const victimUid = "p7-iap-victim";
    const attackerUid = "p7-iap-attacker";
    const key = "p7-original-transaction-c";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", victimUid), userFixture(victimUid));
      await setDoc(doc(fs, "users", attackerUid), userFixture(attackerUid));
      await setDoc(doc(fs, "iapSubscriptions", key), { uid: victimUid, platform: "ios", productId: "peakpin_vip_yearly" });
    });

    const db = testEnv.authenticatedContext(attackerUid).firestore();
    await assertFails(updateDoc(doc(db, "iapSubscriptions", key), { uid: attackerUid }));
  });
});

describe("H #196 — config/iapTesters oxuna bilir, yazıla bilmir", () => {
  test("hər hansı daxil olmuş istifadəçi test siyahısını oxuya bilir (mövcud config/{docId} qaydası)", async () => {
    const uid = "p7-config-reader";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
      await setDoc(doc(fs, "config", "iapTesters"), { testerUids: [uid] });
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, "config", "iapTesters")));
  });

  test("client özünü test siyahısına əlavə edə bilmir", async () => {
    const uid = "p7-config-writer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
      await setDoc(doc(fs, "config", "iapTesters"), { testerUids: [] });
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(updateDoc(doc(db, "config", "iapTesters"), { testerUids: [uid] }));
  });
});
