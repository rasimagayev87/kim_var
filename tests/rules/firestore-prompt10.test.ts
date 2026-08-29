// Düzəliş Prompt 10 — Qalan HIGH/MEDIUM Tapıntılar. Bu promptun əksər
// düzəlişi Cloud Function daxili məntiqdir (AUTH-12 client xəta tutması,
// AUTH-15 IDOR qoruması, forwardChatMedia, onChatDeleted, H #181,
// PAY-24, PAY-28 düsturu) və rules testləri ilə sınana bilməz — qərar
// #5-ə uyğun, rules-səviyyəli əhatə + manual doğrulama. Burada YALNIZ
// AUTH-6-nın rules-səviyyəli hissəsi sınanır (Cloud Function tərəfi
// artıq `completeOnboarding`-də, bu, YALNIZ `updateUsername`-in
// birbaşa client yazı yolunu — rules-un özünü — sınayır).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
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

describe("AUTH-6 — rezerv username-lər usernames/{id} create-də rədd edilir", () => {
  test("'admin' tutmağa cəhd edilir — rədd edilir", async () => {
    const uid = "p10-username-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(setDoc(doc(db, "usernames", "admin"), { uid, createdAt: new Date() }));
  });

  test("'peakpin'/'support'/'moderator' də rədd edilir", async () => {
    const uid = "p10-username-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(setDoc(doc(db, "usernames", "peakpin"), { uid, createdAt: new Date() }));
    await assertFails(setDoc(doc(db, "usernames", "support"), { uid, createdAt: new Date() }));
    await assertFails(setDoc(doc(db, "usernames", "moderator"), { uid, createdAt: new Date() }));
  });

  test("rezerv siyahıda olmayan normal username hələ də tutula bilir (regression)", async () => {
    const uid = "p10-username-c";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uid), userFixture(uid));
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(setDoc(doc(db, "usernames", "p10-normal-user-xyz"), { uid, createdAt: new Date() }));
  });
});
