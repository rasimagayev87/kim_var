// P0 / H-3 — `chats/{chatId}` üzvlüyünün dəyişməzliyi.
//
// Prompt 5 blok / `whoCanMessageMe` yoxlamalarını `create` və
// `messages/create`-ə əlavə etdi, `update`-ə yox. `update`-in 1-ci
// budağı isə "status dəyişməsin, qalan hər şey sərbəst" idi — yəni
// `participants` massivinin özü də. Çat siyahısı `where('participants',
// arrayContains: uid)` sorğusudur, deməli hücumçu istənilən uid-i öz
// çatına "yerləşdirib" ona ixtiyari önizləmə mətni çatdıra bilirdi.
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc, updateDoc } from "firebase/firestore";
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

const ATTACKER = "p0h3-attacker";
const FRIEND = "p0h3-friend";
const VICTIM = "p0h3-victim";
const CHAT = chatIdFor(ATTACKER, FRIEND);

describe("P0 / H-3 — chats.participants dəyişdirilə bilmir", () => {
  beforeEach(async () => {
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", ATTACKER), userFixture(ATTACKER));
      await setDoc(doc(fs, "users", FRIEND), userFixture(FRIEND));
      // Qurban hücumçunu BLOKLAYIB — Prompt 5 mexanizmi.
      await setDoc(doc(fs, "users", VICTIM), userFixture(VICTIM, { blockedUsers: [ATTACKER] }));
      await setDoc(doc(fs, "chats", CHAT), {
        participants: [ATTACKER, FRIEND].sort(),
        initiatorId: ATTACKER,
        status: "accepted",
        lastMessage: "salam",
      });
    });
  });

  test("participants-i bloklanmış qurbana yönəltmək RƏDD EDİLİR (əsas hücum)", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", CHAT), {
        participants: [ATTACKER, VICTIM].sort(),
        lastMessage: "bloku keçən mesaj",
        lastMessageAt: new Date(),
      }),
    );
  });

  test("participants-i bloklanmamış üçüncü şəxsə yönəltmək də RƏDD EDİLİR", async () => {
    const neutral = "p0h3-neutral";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", neutral), userFixture(neutral));
    });
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { participants: [ATTACKER, neutral].sort() }));
  });

  test("initiatorId dəyişdirilə BİLMİR", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertFails(updateDoc(doc(db, "chats", CHAT), { initiatorId: FRIEND }));
  });

  test("adi çat fəaliyyəti (lastMessage/unreadCount/typing) İŞLƏYİR — reqressiya yoxdur", async () => {
    const db = testEnv.authenticatedContext(ATTACKER).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "chats", CHAT), {
        lastMessage: "yeni mesaj",
        lastMessageAt: new Date(),
        lastMessageType: "text",
        unreadCount: { [FRIEND]: 1 },
      }),
    );
  });

  test("gözləyən sorğunun qəbulu İŞLƏYİR — reqressiya yoxdur", async () => {
    const a = "p0h3-pa";
    const b = "p0h3-pb";
    const pendingChat = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", pendingChat), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
      });
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", pendingChat), { status: "accepted" }));
  });

  test("chatId ilə uyğun gəlməyən participants ilə çat YARADILA BİLMİR", async () => {
    const a = "p0h3-ca";
    const b = "p0h3-cb";
    const c = "p0h3-cc";
    await seed(async (fs) => {
      for (const u of [a, b, c]) await setDoc(doc(fs, "users", u), userFixture(u));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    // Sənəd id-si a_b, amma participants a və c — struktur uyğunsuzluğu.
    await assertFails(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, c].sort(),
        initiatorId: a,
        status: "pending",
      }),
    );
  });

  test("sıralanmamış participants ilə çat YARADILA BİLMİR", async () => {
    const a = "p0h3-za";
    const b = "p0h3-ab";
    await seed(async (fs) => {
      for (const u of [a, b]) await setDoc(doc(fs, "users", u), userFixture(u));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, b], // sortsuz: "p0h3-za" > "p0h3-ab"
        initiatorId: a,
        status: "pending",
      }),
    );
  });

  test("düzgün formada çat YARADILA BİLİR — reqressiya yoxdur", async () => {
    const a = "p0h3-oka";
    const b = "p0h3-okb";
    await seed(async (fs) => {
      for (const u of [a, b]) await setDoc(doc(fs, "users", u), userFixture(u));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
      }),
    );
  });
});
