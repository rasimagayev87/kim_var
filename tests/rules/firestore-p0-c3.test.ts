// P0 / C-3 — profil sənədi olmayan (onboarding-i tamamlamamış) hesabın
// ictimai məzmun yarada bilməməsi.
//
// `isActiveUser()` `users/{uid}` sənədinin MÖVCUDLUĞUNU tələb edir, o
// sənəd isə yalnız `completeOnboarding` Cloud Function-ı tərəfindən —
// 18+ yoxlamasından SONRA — yaradılır. Deməli bu qapı eyni anda həm
// banlanmış, həm də yaş qapısından keçməmiş hesabı bloklayır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

// P0 / H-5 — media URL-ləri öz bucket-imizə işarə etməlidir.
const OWN_STORAGE_URL =
  "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/x%2Fy.jpg?alt=media&token=t";

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

// Onboarding-i tamamlamış istifadəçi (users/{uid} MÖVCUDDUR).
const ONBOARDED = "p0c3-onboarded";
// Auth hesabı var, amma `completeOnboarding` rədd edilib —
// users/{uid} sənədi HEÇ VAXT yaradılmayıb (məs. 18 yaşdan kiçik).
const NO_PROFILE = "p0c3-noprofile";
// Onboarding-dən keçib, sonra banlanıb.
const BANNED = "p0c3-banned";

describe("P0 / C-3 — profilsiz hesab ictimai məzmun yarada bilmir", () => {
  before(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", ONBOARDED), userFixture(ONBOARDED));
      await setDoc(doc(fs, "users", BANNED), userFixture(BANNED));
      await setDoc(doc(fs, "bannedUsers", BANNED), { bannedAt: new Date() });
      // NO_PROFILE üçün QƏSDƏN heç bir users/{uid} sənədi yaradılmır.
      await setDoc(doc(fs, "posts", "p0c3-host-post"), {
        userId: ONBOARDED,
        caption: "host",
        authorIsPublic: true,
      });
    });
  });

  test("profilsiz hesab post yarada BİLMİR", async () => {
    const db = testEnv.authenticatedContext(NO_PROFILE).firestore();
    await assertFails(
      setDoc(doc(db, "posts", "p0c3-bad-post"), { userId: NO_PROFILE, caption: "x", mediaUrl: OWN_STORAGE_URL }),
    );
  });

  test("profilsiz hesab story yarada BİLMİR", async () => {
    const db = testEnv.authenticatedContext(NO_PROFILE).firestore();
    await assertFails(
      setDoc(doc(db, "stories", "p0c3-bad-story"), { creatorId: NO_PROFILE, mediaUrl: OWN_STORAGE_URL }),
    );
  });

  test("profilsiz hesab şərh yaza BİLMİR", async () => {
    const db = testEnv.authenticatedContext(NO_PROFILE).firestore();
    await assertFails(
      setDoc(doc(db, "posts", "p0c3-host-post", "comments", "p0c3-bad-comment"), {
        userId: NO_PROFILE,
        text: "x",
      }),
    );
  });

  test("banlanmış hesab da post/story yarada BİLMİR (eyni qapı)", async () => {
    const db = testEnv.authenticatedContext(BANNED).firestore();
    await assertFails(setDoc(doc(db, "posts", "p0c3-banned-post"), { userId: BANNED, caption: "x" }));
    await assertFails(setDoc(doc(db, "stories", "p0c3-banned-story"), { creatorId: BANNED, mediaUrl: OWN_STORAGE_URL }));
  });

  test("onboarding-i tamamlamış hesab post/story/şərh yarada BİLİR (reqressiya yoxdur)", async () => {
    const db = testEnv.authenticatedContext(ONBOARDED).firestore();
    await assertSucceeds(
      setDoc(doc(db, "posts", "p0c3-ok-post"), { userId: ONBOARDED, caption: "ok", authorIsPublic: false }),
    );
    await assertSucceeds(
      setDoc(doc(db, "stories", "p0c3-ok-story"), { creatorId: ONBOARDED, mediaUrl: OWN_STORAGE_URL }),
    );
    await assertSucceeds(
      setDoc(doc(db, "posts", "p0c3-host-post", "comments", "p0c3-ok-comment"), {
        userId: ONBOARDED,
        text: "ok",
      }),
    );
  });

  test("profilsiz hesab HƏLƏ DƏ dəstəyə yaza bilir (qəsdən açıq qapı)", async () => {
    // İlişmiş istifadəçi köməksiz qalmamalıdır — `supportMessages`
    // qəsdən `isActiveUser()` ilə qorunmur.
    const db = testEnv.authenticatedContext(NO_PROFILE).firestore();
    await assertSucceeds(
      setDoc(doc(db, "supportMessages", "p0c3-support"), { uid: NO_PROFILE, message: "kömək" }),
    );
  });
});
