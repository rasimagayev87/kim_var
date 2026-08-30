// Düzəliş Prompt 12 — Prompt 11 (sessiya ləğvi) davranış testləri.
// Əhatə: `isActiveUser()` gate-i olan 5 kolleksiya (messages, calls,
// reports, eventReports, reviewReports), `bannedUsers` kolleksiyasının
// özü, və QƏSDƏN əhatə OLUNMAYAN yollar (posts/stories/pinboxes/
// venueEvents/supportMessages — bax firestore.rules-un öz "ACCEPTED,
// DOCUMENTED RISK" şərhi, faylın sonunda).
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, setDoc } from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (fs: () => ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(() => ctx.firestore()));
}

/** uid1 = users sənədi var (aktiv), uid2 = heç bir users sənədi yoxdur
 * (silinmiş hesab simulyasiyası), uid3 = users sənədi var AMMA
 * bannedUsers-də tombstone-u da var (banlanmış hesab simulyasiyası). */
interface ActorSet {
  active: string;
  deleted: string;
  banned: string;
}

async function seedActors(prefix: string): Promise<ActorSet> {
  const active = `${prefix}-active`;
  const deleted = `${prefix}-deleted`; // qəsdən heç bir users sənədi yaradılmır
  const banned = `${prefix}-banned`;
  await seed(async (fs) => {
    const db = fs();
    await setDoc(doc(db, "users", active), userFixture(active));
    await setDoc(doc(db, "users", banned), userFixture(banned));
    await setDoc(doc(db, "bannedUsers", banned), { bannedAt: new Date() });
  });
  return { active, deleted, banned };
}

// ---------------------------------------------------------------------------
// chats/{chatId}/messages — isActiveUser() gate-inin nümunə kolleksiyası
// ---------------------------------------------------------------------------
describe("Prompt 11 — chats/messages create isActiveUser() ilə qapılıb", () => {
  let actors: ActorSet;
  const chatIdFor = (uid: string) => [uid, "peer"].sort().join("_");

  before(async () => {
    actors = await seedActors("p11-msg");
    await seed(async (fs) => {
      const db = fs();
      for (const uid of [actors.active, actors.deleted, actors.banned]) {
        await setDoc(doc(db, "chats", chatIdFor(uid)), {
          participants: [uid, "peer"].sort(),
          initiatorId: uid,
          status: "accepted",
        });
      }
    });
  });

  test("users sənədi mövcud olan istifadəçi mesaj yaza bilir", async () => {
    const db = testEnv.authenticatedContext(actors.active).firestore();
    const chatId = chatIdFor(actors.active);
    await assertSucceeds(
      setDoc(doc(collection(db, "chats", chatId, "messages")), {
        senderId: actors.active,
        receiverId: "peer",
        type: "text",
        text: "salam",
        sentAt: new Date(),
      }),
    );
  });

  test("users sənədi olmayan uid mesaj yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.deleted).firestore();
    const chatId = chatIdFor(actors.deleted);
    await assertFails(
      setDoc(doc(collection(db, "chats", chatId, "messages")), {
        senderId: actors.deleted,
        receiverId: "peer",
        type: "text",
        text: "salam",
        sentAt: new Date(),
      }),
    );
  });

  test("bannedUsers/{uid} mövcud olan istifadəçi mesaj yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.banned).firestore();
    const chatId = chatIdFor(actors.banned);
    await assertFails(
      setDoc(doc(collection(db, "chats", chatId, "messages")), {
        senderId: actors.banned,
        receiverId: "peer",
        type: "text",
        text: "salam",
        sentAt: new Date(),
      }),
    );
  });
});

describe("Prompt 11 — calls create isActiveUser() ilə qapılıb", () => {
  let actors: ActorSet;

  before(async () => {
    actors = await seedActors("p11-call");
  });

  test("users sənədi mövcud olan istifadəçi zəng yarada bilir", async () => {
    const db = testEnv.authenticatedContext(actors.active).firestore();
    await assertSucceeds(
      setDoc(doc(db, "calls", `${actors.active}-call`), {
        callerId: actors.active,
        receiverId: "peer",
        participants: [actors.active, "peer"],
        status: "ringing",
      }),
    );
  });

  test("users sənədi olmayan uid zəng yaratmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.deleted).firestore();
    await assertFails(
      setDoc(doc(db, "calls", `${actors.deleted}-call`), {
        callerId: actors.deleted,
        receiverId: "peer",
        participants: [actors.deleted, "peer"],
        status: "ringing",
      }),
    );
  });

  test("bannedUsers/{uid} mövcud olan istifadəçi zəng yaratmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.banned).firestore();
    await assertFails(
      setDoc(doc(db, "calls", `${actors.banned}-call`), {
        callerId: actors.banned,
        receiverId: "peer",
        participants: [actors.banned, "peer"],
        status: "ringing",
      }),
    );
  });
});

describe("Prompt 11 — reports create isActiveUser() ilə qapılıb", () => {
  let actors: ActorSet;

  before(async () => {
    actors = await seedActors("p11-report");
  });

  test("users sənədi mövcud olan istifadəçi şikayət yaza bilir", async () => {
    const db = testEnv.authenticatedContext(actors.active).firestore();
    await assertSucceeds(
      setDoc(doc(collection(db, "reports")), { reporterId: actors.active, reportedId: "someone", reason: "spam" }),
    );
  });

  test("users sənədi olmayan uid şikayət yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.deleted).firestore();
    await assertFails(
      setDoc(doc(collection(db, "reports")), { reporterId: actors.deleted, reportedId: "someone", reason: "spam" }),
    );
  });

  test("bannedUsers/{uid} mövcud olan istifadəçi şikayət yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.banned).firestore();
    await assertFails(
      setDoc(doc(collection(db, "reports")), { reporterId: actors.banned, reportedId: "someone", reason: "spam" }),
    );
  });
});

describe("Prompt 11 — eventReports create isActiveUser() ilə qapılıb", () => {
  let actors: ActorSet;

  before(async () => {
    actors = await seedActors("p11-eventreport");
  });

  test("users sənədi mövcud olan istifadəçi tədbir şikayəti yaza bilir", async () => {
    const db = testEnv.authenticatedContext(actors.active).firestore();
    await assertSucceeds(
      setDoc(doc(collection(db, "eventReports")), { reportedBy: actors.active, eventId: "some-event", reason: "spam" }),
    );
  });

  test("users sənədi olmayan uid tədbir şikayəti yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.deleted).firestore();
    await assertFails(
      setDoc(doc(collection(db, "eventReports")), { reportedBy: actors.deleted, eventId: "some-event", reason: "spam" }),
    );
  });

  test("bannedUsers/{uid} mövcud olan istifadəçi tədbir şikayəti yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.banned).firestore();
    await assertFails(
      setDoc(doc(collection(db, "eventReports")), { reportedBy: actors.banned, eventId: "some-event", reason: "spam" }),
    );
  });
});

describe("Prompt 11 — reviewReports create isActiveUser() ilə qapılıb", () => {
  let actors: ActorSet;

  before(async () => {
    actors = await seedActors("p11-reviewreport");
  });

  test("users sənədi mövcud olan istifadəçi rəy şikayəti yaza bilir", async () => {
    const db = testEnv.authenticatedContext(actors.active).firestore();
    await assertSucceeds(
      setDoc(doc(collection(db, "reviewReports")), { reporterId: actors.active, reviewId: "some-review", reason: "spam" }),
    );
  });

  test("users sənədi olmayan uid rəy şikayəti yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.deleted).firestore();
    await assertFails(
      setDoc(doc(collection(db, "reviewReports")), { reporterId: actors.deleted, reviewId: "some-review", reason: "spam" }),
    );
  });

  test("bannedUsers/{uid} mövcud olan istifadəçi rəy şikayəti yazmağa cəhd edərsə rədd edilir", async () => {
    const db = testEnv.authenticatedContext(actors.banned).firestore();
    await assertFails(
      setDoc(doc(collection(db, "reviewReports")), { reporterId: actors.banned, reviewId: "some-review", reason: "spam" }),
    );
  });
});

// ---------------------------------------------------------------------------
// bannedUsers kolleksiyasının özü — client-dən tam bağlıdır
// ---------------------------------------------------------------------------
describe("Prompt 11 — bannedUsers kolleksiyası client-dən əlçatan deyil", () => {
  const uid = "p11-bannedusers-collection";

  before(async () => {
    await seed(async (fs) => setDoc(doc(fs(), "bannedUsers", uid), { bannedAt: new Date() }));
  });

  test("client oxuya bilmir", async () => {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDoc(doc(db, "bannedUsers", uid)));
  });

  test("client yaza bilmir", async () => {
    const db = testEnv.authenticatedContext("p11-bannedusers-writer").firestore();
    await assertFails(setDoc(doc(db, "bannedUsers", "p11-bannedusers-writer"), { bannedAt: new Date() }));
  });
});

// ---------------------------------------------------------------------------
// QƏSDƏN əhatə olunmayan yollar — banlanmış istifadəçi HƏLƏ DƏ yaza bilir.
// Bu testlər BUG DEYİL, sənədləşdirilmiş, qəbul edilmiş qərardır (Prompt
// 11-in Variant B qərarı) — "keçir" gözləntisi ilə yazılıb ki, gələcəkdə
// kimsə bunu səhvən "düzəldilməli boşluq" saymasın.
//
// P0 / C-3 YENİLƏNMƏSİ (2026-08-30) — `posts` və `stories` bu siyahıdan
// ÇIXARILDI və aşağıdakı iki test "keçir"dən "rədd edilir"ə çevrildi.
// Səbəb Variant B-nin öz mühakiməsinin dəyişməsi DEYİL (banlanmış
// hesabın məzmun yaratmasının xərc-fayda balansı eyni qalır) — səbəb
// odur ki, `isActiveUser()` eyni anda `users/{uid}` sənədi ÜMUMİYYƏTLƏ
// olmayan hesabları da bloklayır, yəni `completeOnboarding`-in 18+
// qapısından keçməmişləri. Bu, artıq moderasiya xərci məsələsi deyil,
// uşaq təhlükəsizliyi məsələsidir. `pinboxes`/`venueEvents`/
// `supportMessages` qəsdən açıq qalır (aşağıdakı 3 test dəyişmir);
// `supportMessages` xüsusilə — ilişmiş istifadəçi dəstəyə yaza bilməlidir.
// ---------------------------------------------------------------------------
describe("Prompt 11 — qəsdən açıq qalan yollar (P0 / C-3-dən sonra: posts/stories artıq bağlıdır)", () => {
  const banned = "p11-open-banned";
  const venueId = "p11-open-venue";

  before(async () => {
    await seed(async (fs) => {
      const db = fs();
      await setDoc(doc(db, "users", banned), userFixture(banned));
      await setDoc(doc(db, "bannedUsers", banned), { bannedAt: new Date() });
      await setDoc(doc(db, "venues", venueId), venueFixture(banned));
    });
  });

  test("BAĞLANDI (P0 / C-3) — banlanmış istifadəçi post yaza BİLMİR", async () => {
    const db = testEnv.authenticatedContext(banned).firestore();
    await assertFails(setDoc(doc(collection(db, "posts")), { userId: banned, caption: "test", createdAt: new Date() }));
  });

  test("BAĞLANDI (P0 / C-3) — banlanmış istifadəçi story yaza BİLMİR", async () => {
    const db = testEnv.authenticatedContext(banned).firestore();
    await assertFails(setDoc(doc(collection(db, "stories")), { creatorId: banned, mediaUrl: "https://example.com/s.jpg" }));
  });

  test("hələ açıqdır — banlanmış istifadəçi (öz venue-sinə) pinbox yaza bilir", async () => {
    const db = testEnv.authenticatedContext(banned).firestore();
    await assertSucceeds(
      setDoc(doc(db, "pinboxes", "p11-open-pinbox"), {
        ownerId: banned,
        venueId,
        status: "pending",
        stockTotal: 5,
        stockRemaining: 5,
        title: "Test",
      }),
    );
  });

  test("hələ açıqdır — banlanmış istifadəçi (öz venue-sinə) tədbir yaza bilir", async () => {
    const db = testEnv.authenticatedContext(banned).firestore();
    await assertSucceeds(
      setDoc(doc(db, "venueEvents", "p11-open-event"), {
        venueId,
        status: "upcoming",
        title: "Test",
      }),
    );
  });

  test("hələ açıqdır — banlanmış istifadəçi support mesajı yaza bilir", async () => {
    const db = testEnv.authenticatedContext(banned).firestore();
    await assertSucceeds(setDoc(doc(collection(db, "supportMessages")), { uid: banned, message: "kömək lazımdır" }));
  });
});

// Say: 22 test (5 kolleksiya × 3 hal = 15, bannedUsers özü = 2,
// qəsdən-açıq 3 yol + P0/C-3 ilə bağlanmış 2 yol = 5).
