// Produksiyada `documentReferenceUpdate` üzərində `permission-denied`
// çökmələri göründü. Fərziyyə: `private/data` sənədi MÖVCUD DEYİLSƏ,
// qaydadakı `diff(resource.data)` qiymətləndirmə xətası verir və
// Firestore onu `not-found` yox, `permission-denied` kimi qaytarır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
before(async () => { testEnv = await createTestEnv(); });
after(async () => { await testEnv.cleanup(); });

const U = "pdm-user";
const priv = (uid: string) => ["users", uid, "private", "data"] as const;

describe("private/data mövcud olmayanda update", () => {
  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      // İstifadəçi sənədi var, PRIVATE sənədi YOXDUR.
      await setDoc(doc(ctx.firestore(), "users", U), userFixture(U));
    });
  });

  test("mövcud OLMAYAN private sənədə update RƏDD EDİLİR", async () => {
    // Məhz bu hal: `activeChatId` yazısı (`_setActiveChatId`,
    // `unawaited`, xəta emalı yoxdur) belə bir hesabda hər çat
    // açılışında rədd edilir və tutulmamış xəta kimi Crashlytics-ə
    // düşür.
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertFails(updateDoc(doc(fs, ...priv(U)), { activeChatId: "c1" }));
  });

  test("set(merge) isə İŞLƏYİR — sənədi yaradır", async () => {
    // Fərq budur: `update` mövcudluq tələb edir, `set(merge)` yox.
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(setDoc(doc(fs, ...priv(U)), { activeChatId: "c1" }, { merge: true }));
  });

  test("sənəd yarandıqdan sonra update işləyir", async () => {
    const fs = testEnv.authenticatedContext(U).firestore();
    await assertSucceeds(updateDoc(doc(fs, ...priv(U)), { activeChatId: "c2" }));
  });
});
