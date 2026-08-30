// P0 / C-1 — `chats/{chatId}/messages` `mediaUrl` şəkil yoxlaması
// (DƏRİNLİKDƏ MÜDAFİƏ qatı).
//
// Əsl sərhəd `functions/src/chat-media.ts`-dədir və `chat-media-path
// .test.ts`-də ayrıca test olunur — server silinəcək yolu artıq
// `mediaUrl`-dən OXUMUR. Buradakı qayda yalnız sahənin ixtiyari sətir
// saxlaya bilməməsini təmin edir; TƏK BAŞINA sərhəd deyil (URL-in
// prefiksini məhdudlaşdırır, içindəki obyekt yolunu yox).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, serverTimestamp, setDoc } from "firebase/firestore";
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

const chatIdFor = (a: string, b: string) => [a, b].sort().join("_");

const A = "p0c1-a";
const B = "p0c1-b";
const CHAT = chatIdFor(A, B);

const STORAGE_URL =
  "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/" +
  `chat_photos%2F${CHAT}%2F${A}%2Fm1.jpg?alt=media&token=abc`;

describe("P0 / C-1 — mediaUrl şəkil yoxlaması (dərinlikdə müdafiə)", () => {
  before(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", A), userFixture(A));
      await setDoc(doc(fs, "users", B), userFixture(B));
      await setDoc(doc(fs, "chats", CHAT), {
        participants: [A, B].sort(),
        initiatorId: A,
        status: "accepted",
      });
    });
  });

  const message = (overrides: Record<string, unknown>) => ({
    senderId: A,
    receiverId: B,
    sentAt: serverTimestamp(),
    ...overrides,
  });

  test("real Firebase Storage URL-i olan media mesajı keçir", async () => {
    const db = testEnv.authenticatedContext(A).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", CHAT, "messages", "ok1"), message({ type: "image", mediaUrl: STORAGE_URL })),
    );
  });

  test("mediaUrl-siz mətn mesajı keçir (sahə opsionaldır)", async () => {
    const db = testEnv.authenticatedContext(A).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", CHAT, "messages", "ok2"), message({ type: "text", text: "salam" })),
    );
  });

  test("`/o/` daşıyan, amma Storage host-u olmayan uydurma mediaUrl rədd edilir", async () => {
    // Auditdəki C-1 hücumunun tam yükü: "x/o/profile_photos%2F...".
    const db = testEnv.authenticatedContext(A).firestore();
    await assertFails(
      setDoc(
        doc(db, "chats", CHAT, "messages", "bad1"),
        message({ type: "image", mediaUrl: `x/o/profile_photos%2F${B}%2Fprofile.jpg` }),
      ),
    );
  });

  test("başqa host-da yerləşən mediaUrl rədd edilir", async () => {
    const db = testEnv.authenticatedContext(A).firestore();
    await assertFails(
      setDoc(
        doc(db, "chats", CHAT, "messages", "bad2"),
        message({
          type: "image",
          mediaUrl: "https://evil.test/o/identity_verifications%2Fvictim%2Freq%2Fselfie.jpg",
        }),
      ),
    );
  });

  test("boş sətir mediaUrl rədd edilir", async () => {
    const db = testEnv.authenticatedContext(A).firestore();
    await assertFails(setDoc(doc(db, "chats", CHAT, "messages", "bad3"), message({ type: "image", mediaUrl: "" })));
  });

  test("paylaşılan postun mediaUrl-i (posts/ yolu, real Storage host) keçməyə davam edir", async () => {
    // A-2 ilə əlaqəli: `post` tipli mesaj legitim olaraq posts/{uid}/...
    // obyektinə işarə edir. Qayda host səviyyəsindədir, ona görə bu axın
    // pozulmur — və server tərəf onu artıq SİLMİR (chat-media.ts).
    const db = testEnv.authenticatedContext(A).firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "chats", CHAT, "messages", "ok3"),
        message({
          type: "post",
          postId: "post1",
          postIsVideo: false,
          mediaUrl:
            "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/" +
            "posts%2Fsomeone%2Fclip.mp4?alt=media&token=abc",
        }),
      ),
    );
  });
});
