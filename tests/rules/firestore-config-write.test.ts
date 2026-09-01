// `config/features.callsEnabled` zəngin server tərəfdəki açarıdır.
// Klient onu yaza bilsəydi, gizlədilmiş funksiya arxa qapıdan açılardı.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc, deleteDoc, getDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
before(async () => { testEnv = await createTestEnv(); });
after(async () => { await testEnv.cleanup(); });

const U = "config-user";

describe("config kolleksiyası — yalnız server yazır", () => {
  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users", U), userFixture(U));
      await setDoc(doc(ctx.firestore(), "config", "features"), { callsEnabled: false });
    });
  });

  test("daxil olmuş istifadəçi OXUYA bilir", async () => {
    // Klient bayrağı oxumalıdır — gizlətmə sirr deyil, sadəcə yazıla
    // bilməyən olmalıdır.
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(getDoc(doc(fs, "config", "features")));
  });

  test("callsEnabled-i true etmək RƏDD EDİLİR", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(fs, "config", "features"), { callsEnabled: true }));
  });

  test("sənədi üzərinə yazmaq RƏDD EDİLİR", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(setDoc(doc(fs, "config", "features"), { callsEnabled: true }));
  });

  test("silmək RƏDD EDİLİR — yoxluq da server üçün `false` deməkdir, amma silinməməlidir", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(deleteDoc(doc(fs, "config", "features")));
  });

  test("yeni config sənədi yaratmaq RƏDD EDİLİR", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(setDoc(doc(fs, "config", "uydurma"), { x: 1 }));
  });

  test("imzasız yazı da RƏDD EDİLİR", async () => {
    const fs = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(fs, "config", "features"), { callsEnabled: true }));
  });
});
