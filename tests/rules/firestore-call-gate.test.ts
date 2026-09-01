/**
 * `calls/{callId}` create — the accepted-conversation gate.
 *
 * The product rule has always been "you cannot call someone who has
 * not accepted your message request", but until now it lived only in
 * the chat UI (`callsEnabled` / `_startCall`'s own check in
 * chat_conversation_screen.dart). A modified client calling
 * `startCall()` directly went straight past it, and the rules file's
 * own comment said so.
 *
 * That mattered little while an incoming call reached nobody. It
 * matters a great deal now that a call wakes a locked phone with a
 * full-screen notification.
 */
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture } from "./helpers.ts";

let env: RulesTestEnvironment;
const A = "cg-alice";
const B = "cg-bob";
const C = "cg-carol";      // accepted chat with nobody
const D = "cg-dave";       // legacy chat, no `status` field

const chatId = (x: string, y: string) => [x, y].sort().join("_");

function callDoc(caller: string, receiver: string, overrides: Record<string, unknown> = {}) {
  return {
    callerId: caller,
    receiverId: receiver,
    participants: [caller, receiver],
    type: "voice",
    status: "ringing",
    createdAt: new Date(),
    ...overrides,
  };
}

before(async () => {
  env = await createTestEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    for (const u of [A, B, C, D]) await setDoc(doc(fs, "users", u), userFixture(u));

    await setDoc(doc(fs, "chats", chatId(A, B)), {
      participants: [A, B].sort(), status: "accepted", createdAt: new Date(),
    });
    // A message request Carol has not answered.
    await setDoc(doc(fs, "chats", chatId(A, C)), {
      participants: [A, C].sort(), status: "pending", createdAt: new Date(),
    });
    // A conversation from before "Hesab gizliliyi" introduced `status`.
    await setDoc(doc(fs, "chats", chatId(A, D)), {
      participants: [A, D].sort(), createdAt: new Date(),
    });
  });
});
after(async () => { await env.cleanup(); });

describe("zəng — qəbul edilmiş söhbət tələb olunur", () => {
  test("qəbul edilmiş çatda zəng edilə bilir", async () => {
    const db = env.authenticatedContext(A).firestore();
    await assertSucceeds(setDoc(doc(db, "calls", "cg-ok"), callDoc(A, B)));
  });

  test("HƏR İKİ istiqamətdə işləyir — çat id-si sıralanmışdır", async () => {
    // Qayda `a < b ? a+'_'+b : b+'_'+a` ilə id qurur. Sıralama səhv
    // olsaydı, cütün yalnız bir istiqaməti işləyərdi — və bunu yalnız
    // istifadəçi şikayət edəndə bilərdik.
    const db = env.authenticatedContext(B).firestore();
    await assertSucceeds(setDoc(doc(db, "calls", "cg-ok-rev"), callDoc(B, A)));
  });

  test("`pending` çatda zəng RƏDD edilir", async () => {
    // Taciz vektorunun özü: qəbul edilməmiş mesaj istəyi göndərib
    // sonra qurbanın telefonunu tam ekran zənglə oyatmaq.
    const db = env.authenticatedContext(A).firestore();
    await assertFails(setDoc(doc(db, "calls", "cg-pending"), callDoc(A, C)));
  });

  test("çat ÜMUMİYYƏTLƏ yoxdursa zəng rədd edilir", async () => {
    const db = env.authenticatedContext(C).firestore();
    await assertFails(setDoc(doc(db, "calls", "cg-nochat"), callDoc(C, D)));
  });

  test("`status` sahəsi olmayan KÖHNƏ çat qəbul edilmiş sayılır", async () => {
    // "Hesab gizliliyi"ndən əvvəl yaradılmış çatlarda bu sahə yoxdur.
    // Defolt `accepted` olmasaydı, şərt mövcud istifadəçilərin
    // hamısını bloklayardı — deploy anında sınan növ dəyişiklik.
    // `isFollowAccepted` eyni defoltu işlədir.
    const db = env.authenticatedContext(A).firestore();
    await assertSucceeds(setDoc(doc(db, "calls", "cg-legacy"), callDoc(A, D)));
  });
});

describe("zəng — mövcud qatlar pozulmayıb", () => {
  test("başqasının adından zəng yaradıla bilmir", async () => {
    const db = env.authenticatedContext(B).firestore();
    await assertFails(setDoc(doc(db, "calls", "cg-spoof"), callDoc(A, B)));
  });

  test("`ringing`-dən başqa statusla yaradıla bilmir", async () => {
    const db = env.authenticatedContext(A).firestore();
    await assertFails(setDoc(doc(db, "calls", "cg-accepted"), callDoc(A, B, { status: "accepted" })));
  });

  test("anonim zəng edə bilmir", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, "calls", "cg-anon"), callDoc(A, B)));
  });
});
