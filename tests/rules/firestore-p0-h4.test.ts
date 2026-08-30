// P0 / H-4 — "Söhbəti sil" per-user gizlətməyə çevrildi.
//
// Əvvəl bir iştirakçının silməsi PAYLAŞILAN sənədi silirdi və
// `onChatDeleted` kaskadı hər iki tərəfin mesajlarını və Storage
// fayllarını aparırdı — yəni tacizçi qurbanın öz hesabından sübutu
// məhv edə bilirdi. İndi: client silə bilmir, yalnız ÖZ `hiddenFor`
// açarını yaza bilər.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, setDoc, updateDoc } from "firebase/firestore";
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

const ABUSER = "p0h4-abuser";
const VICTIM = "p0h4-victim";
const CHAT = chatIdFor(ABUSER, VICTIM);

async function seedChat(hiddenFor: Record<string, boolean> = {}) {
  await seed(async (fs) => {
    await setDoc(doc(fs, "users", ABUSER), userFixture(ABUSER));
    await setDoc(doc(fs, "users", VICTIM), userFixture(VICTIM));
    await setDoc(doc(fs, "chats", CHAT), {
      participants: [ABUSER, VICTIM].sort(),
      initiatorId: ABUSER,
      status: "accepted",
      lastMessage: "təhqiramiz mesaj",
      hiddenFor,
    });
  });
}

describe("P0 / H-4 — paylaşılan çat sənədi client tərəfindən silinə bilmir", () => {
  beforeEach(() => seedChat());

  test("iştirakçı çatı SİLƏ BİLMİR (əsas hücum — sübutun məhvi)", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(deleteDoc(doc(db, "chats", CHAT)));
  });

  test("qarşı tərəf də silə bilmir (simmetrik)", async () => {
    const db = testEnv.authenticatedContext(VICTIM).firestore();
    await assertFails(deleteDoc(doc(db, "chats", CHAT)));
  });
});

describe("P0 / H-4 — hiddenFor yalnız öz uid-i üçün yazıla bilər", () => {
  beforeEach(() => seedChat());

  test("istifadəçi ÖZ bayrağını qoya bilir", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${ABUSER}`]: true }));
  });

  test("istifadəçi öz bayrağını geri götürə bilir", async () => {
    await seedChat({ [ABUSER]: true });
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${ABUSER}`]: false }));
  });

  test("QARŞI TƏRƏFİN bayrağını QOYA BİLMİR (qurbanın söhbətini gizlətmək)", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${VICTIM}`]: true }));
  });

  test("QARŞI TƏRƏFİN bayrağını SİLƏ BİLMİR (gizlədilmiş söhbəti geri qaytarmaq)", async () => {
    await seedChat({ [VICTIM]: true });
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${VICTIM}`]: false }));
  });

  test("hər iki bayrağı eyni yazıda qoya bilmir", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", CHAT), {
        [`hiddenFor.${ABUSER}`]: true,
        [`hiddenFor.${VICTIM}`]: true,
      }),
    );
  });

  test("bütün hiddenFor map-ini əvəz edə bilmir", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { hiddenFor: { [VICTIM]: true } }));
  });

  test("hiddenFor-u başqa sahə ilə birlikdə yazmaq rədd edilir (dar budaq)", async () => {
    // `touchesOnlyOwnHiddenFlag` `hasOnly(['hiddenFor'])` tələb edir,
    // 1-ci budaq isə `hiddenFor`-u istisna edir — yəni heç bir budaq
    // qarışıq yazını qəbul etmir.
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${ABUSER}`]: true, lastMessage: "dəyişdirildi" }),
    );
  });

  test("çatın iştirakçısı OLMAYAN kənar şəxs heç nə yaza bilmir", async () => {
    const outsider = "p0h4-outsider";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", outsider), userFixture(outsider));
    });
    const db = testEnv.authenticatedContext(outsider).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { [`hiddenFor.${outsider}`]: true }));
  });

  test("hiddenFor sahəsi olmayan KÖHNƏ çatda da öz bayrağı qoyula bilir", async () => {
    // Miqrasiyadan əvvəlki sənədlərdə sahə ümumiyyətlə yoxdur —
    // `.get('hiddenFor', {})` olmasaydı bunların hamısı rədd edilərdi.
    const a = "p0h4-olda";
    const b = "p0h4-oldb";
    const oldChat = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", oldChat), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "accepted",
      });
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", oldChat), { [`hiddenFor.${a}`]: true }));
  });
});

describe("P0 / H-4 — mövcud çat davranışı pozulmayıb", () => {
  beforeEach(() => seedChat());

  test("adi mesaj fəaliyyəti işləyir", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "chats", CHAT), {
        lastMessage: "salam",
        lastMessageAt: new Date(),
        unreadCount: { [VICTIM]: 1 },
      }),
    );
  });

  test("pinnedBy/archivedBy/mutedBy hələ sərbəstdir (H-4 onlara toxunmur)", async () => {
    const db = testEnv.authenticatedContext(ABUSER).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", CHAT), { [`archivedBy.${ABUSER}`]: true }));
    await assertSucceeds(updateDoc(doc(db, "chats", CHAT), { [`mutedBy.${ABUSER}`]: true }));
  });
});
