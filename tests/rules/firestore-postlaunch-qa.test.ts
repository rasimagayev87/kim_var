// Post-launch QA (Qeydiyyat axını sınağı zamanı tapılmış) — `resource ==
// null ||` mühafizəsi əlavə edilmiş 5 kolleksiyanın hamısı üçün "mövcud
// olmayan sənədin oxunması icazəlidir (permission-denied YOX)" testi.
// Kök səbəb: `resource.data.field` sənəd heç mövcud olmayanda
// (`resource == null`) qiymətləndirilə bilmirdi və Firestore bunu real
// icazə rəddi kimi bağlayırdı — `users/{userId}` üçün bu, HƏR yeni
// qeydiyyatı qırırdı (`_hydrateFromFirestore` `completeOnboarding`-dən
// ƏVVƏL öz sənədini oxuyur, o an sənəd yoxdur). Eyni naxış audit zamanı
// bu 5 yerdə də tapıldı; `users/{userId}`-in öz testləri
// firestore-prompt5.test.ts-dədir (K-3 bölməsi) — bu fayl YALNIZ yeni
// düzəlişləri əhatə edir, mövcud sahiblik/blok davranışını təkrar test
// etmir (o testlər öz prompt fayllarında artıq var).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";
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

describe("Post-launch QA — follows/{followId}: mövcud olmayan sənəd", () => {
  test("heç bir əlaqə yoxdursa .get() icazəlidir (boş nəticə)", async () => {
    const viewer = "qa-follows-viewer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", viewer), userFixture(viewer));
    });
    const db = testEnv.authenticatedContext(viewer).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "follows", "qa-follows-a_qa-follows-b")));
    if (snap.exists()) throw new Error("Sənəd mövcud olmamalı idi");
  });
});

describe("Post-launch QA — calls/{callId}: mövcud olmayan sənəd", () => {
  test("bitmiş/silinmiş zəng ID-si ilə .get() icazəlidir (boş nəticə)", async () => {
    const viewer = "qa-calls-viewer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", viewer), userFixture(viewer));
    });
    const db = testEnv.authenticatedContext(viewer).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "calls", "qa-calls-nonexistent")));
    if (snap.exists()) throw new Error("Sənəd mövcud olmamalı idi");
  });
});

describe("Post-launch QA — savedCards/{cardId}: mövcud olmayan sənəd", () => {
  test("silinmiş kart ID-si ilə .get() icazəlidir (boş nəticə)", async () => {
    const viewer = "qa-savedcards-viewer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", viewer), userFixture(viewer));
    });
    const db = testEnv.authenticatedContext(viewer).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "savedCards", "qa-savedcards-nonexistent")));
    if (snap.exists()) throw new Error("Sənəd mövcud olmamalı idi");
  });
});

describe("Post-launch QA — stories/{storyId}: mövcud olmayan sənəd", () => {
  test("bitmiş/silinmiş story ID-si ilə .get() icazəlidir (boş nəticə)", async () => {
    const viewer = "qa-stories-viewer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", viewer), userFixture(viewer));
    });
    const db = testEnv.authenticatedContext(viewer).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "stories", "qa-stories-nonexistent")));
    if (snap.exists()) throw new Error("Sənəd mövcud olmamalı idi");
  });
});

describe("Post-launch QA — posts/{postId}: mövcud olmayan sənəd + LIST sorğusu reqressiyası", () => {
  test("silinmiş post ID-si ilə .get() icazəlidir (boş nəticə)", async () => {
    const viewer = "qa-posts-viewer";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", viewer), userFixture(viewer));
    });
    const db = testEnv.authenticatedContext(viewer).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, "posts", "qa-posts-nonexistent")));
    if (snap.exists()) throw new Error("Sənəd mövcud olmamalı idi");
  });

  // `resource == null ||` əlavəsinin `posts/{postId}` qaydasının LIST
  // sorğu "provability"-sinə (Firestore-un query-ni per-sənəd simulyasiya
  // etmədən sübut edə bilməsi tələbi — bax bu qaydanın öz şərhi) mənfi
  // təsir GÖSTƏRMƏDİYİNİ EMPİRİK yoxlayır. `watchUserPosts`-un öz "mənim
  // paylaşımlarım" sorğusunun EYNİ şəklidir: `where('userId','==',uid)`.
  test("'mənim paylaşımlarım' LIST sorğusu (where userId==uid) düzəlişdən sonra da işləyir (reqressiya)", async () => {
    const owner = "qa-posts-list-owner";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "posts", "qa-posts-list-1"), {
        userId: owner,
        caption: "test 1",
        authorIsPublic: true,
        createdAt: new Date(),
      });
      await setDoc(doc(fs, "posts", "qa-posts-list-2"), {
        userId: owner,
        caption: "test 2",
        authorIsPublic: true,
        createdAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(owner).firestore();
    const q = query(collection(db, "posts"), where("userId", "==", owner));
    const snap = await assertSucceeds(getDocs(q));
    if (snap.size !== 2) throw new Error(`Gözlənilən 2 sənəd, alındı: ${snap.size}`);
  });
});

// Yeni tapıntı — "chat siyahısındakı son mesaj önizləməsi silinəndən sonra
// yenilənmir" (chats/{chatId}.lastMessage* + yeni lastMessageOverride).
// Bu bölmə YALNIZ `lastMessageOverride`-ın client-dən yazıla bilmədiyini
// sınayır — `onChatMessageDeleted`/`onChatMessageDeletedForUser`
// trigger-lərinin ÖZÜ (hansı sahələri necə yenilədiyi) bu paketin xaricindədir,
// çünki bu suite yalnız Firestore emulator-u işlədir, Functions emulator-u
// YOX — trigger davranışı deploy-dan sonra canlıda yoxlanılıb.
describe("Post-launch QA — chats/{chatId}.lastMessageOverride: client-dən yazıla bilmir", () => {
  const uidA = "qa-lmo-a";
  const uidB = "qa-lmo-b";
  const chatId = `${uidA}_${uidB}`;

  async function seedChat() {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", uidA), userFixture(uidA));
      await setDoc(doc(fs, "users", uidB), userFixture(uidB));
      await setDoc(doc(fs, "chats", chatId), {
        participants: [uidA, uidB],
        initiatorId: uidA,
        status: "accepted",
        lastMessage: "salam",
        lastMessageType: "text",
        lastMessageAt: new Date(),
        lastMessageSenderId: uidA,
        createdAt: new Date(),
      });
    });
  }

  test("iştirakçı ÖZ uid-i altında belə lastMessageOverride yaza bilmir (status dəyişməsə belə)", async () => {
    await seedChat();
    const db = testEnv.authenticatedContext(uidB).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", chatId), {
        [`lastMessageOverride.${uidB}`]: { text: "fabricated", type: "text", at: new Date() },
      }),
    );
  });

  test("iştirakçı BAŞQASININ uid-i altında lastMessageOverride yaza bilmir (qarşı tərəfin önizləməsini saxtalaşdırma cəhdi)", async () => {
    await seedChat();
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", chatId), {
        [`lastMessageOverride.${uidB}`]: { text: "fabricated for the other side", type: "text", at: new Date() },
      }),
    );
  });

  test("regressiya — lastMessageOverride-a toxunmayan adi sahə yeniləməsi (status dəyişməz) hələ də keçir", async () => {
    await seedChat();
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", chatId), { typingUserId: uidA }));
  });
});
