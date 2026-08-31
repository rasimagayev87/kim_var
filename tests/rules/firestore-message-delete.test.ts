// «Hamı üçün sil» — rules həqiqətən icazə verirmi.
//
// Production-da hər iki mesaj `deletedFor` ilə qaldı, yəni «hamı üçün
// sil» icra olunmadı. Kod oxuması zəncirin hər halqasını təmiz
// göstərdi; bu test onun bir halqasını — rules-u — təxmin yerinə
// sübutla bağlayır.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { arrayUnion, deleteDoc, doc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;
const A = "msgdel-alice";
const B = "msgdel-bob";
const CHAT = [A, B].sort().join("_");

before(async () => {
  testEnv = await createTestEnv();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const uid of [A, B]) await setDoc(doc(fs, "users", uid), userFixture(uid));
    await setDoc(doc(fs, "chats", CHAT), {
      participants: [A, B].sort(), initiatorId: A, status: "accepted", createdAt: new Date(),
    });
  });
});
after(async () => { await testEnv.cleanup(); });

async function seedMessage(id: string, sender: string) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "chats", CHAT, "messages", id), {
      senderId: sender, receiverId: sender === A ? B : A, type: "text", text: "salam", sentAt: new Date(),
    });
  });
}

describe("mesaj silmə — rules", () => {
  test("göndərən öz mesajını SİLƏ BİLİR (hamı üçün sil)", async () => {
    await seedMessage("m1", A);
    const db = testEnv.authenticatedContext(A).firestore();
    await assertSucceeds(deleteDoc(doc(db, "chats", CHAT, "messages", "m1")));
  });

  test("alan başqasının mesajını silə BİLMİR", async () => {
    await seedMessage("m2", A);
    const db = testEnv.authenticatedContext(B).firestore();
    await assertFails(deleteDoc(doc(db, "chats", CHAT, "messages", "m2")));
  });

  test("kənar şəxs silə bilmir", async () => {
    await seedMessage("m3", A);
    const db = testEnv.authenticatedContext("msgdel-mallory").firestore();
    await assertFails(deleteDoc(doc(db, "chats", CHAT, "messages", "m3")));
  });

  test("«məndən sil» — yalnız öz uid-ini deletedFor-a əlavə edə bilir", async () => {
    await seedMessage("m4", A);
    const db = testEnv.authenticatedContext(B).firestore();
    // `updateDoc` + `arrayUnion` — məhz client-in `deleteMessageForMe`
    // etdiyi şey. `setDoc` bütün sənədi əvəz etdiyi üçün qayda onu
    // (haqlı olaraq) rədd edir: diff yalnız `deletedFor` olmalıdır.
    await assertSucceeds(
      updateDoc(doc(db, "chats", CHAT, "messages", "m4"), { deletedFor: arrayUnion(B) }),
    );
  });

  test("«məndən sil» başqasının uid-ini əlavə edə BİLMİR", async () => {
    await seedMessage("m5", A);
    const db = testEnv.authenticatedContext(B).firestore();
    await assertFails(
      updateDoc(doc(db, "chats", CHAT, "messages", "m5"), { deletedFor: arrayUnion(A) }),
    );
  });

  test("bütün sənədi əvəz edən yazı rədd edilir", async () => {
    // Qayda diff-in YALNIZ `deletedFor` olmasını tələb edir — yəni
    // «məndən sil» bəhanəsi ilə mesajın mətnini dəyişmək olmaz.
    await seedMessage("m6", A);
    const db = testEnv.authenticatedContext(B).firestore();
    await assertFails(
      setDoc(doc(db, "chats", CHAT, "messages", "m6"),
        { senderId: A, receiverId: B, type: "text", text: "DƏYİŞDİRİLDİ", sentAt: new Date(), deletedFor: [B] }),
    );
  });
});
