// Düzəliş Prompt 12 — Prompt 2 (rules sərtləşdirmə paketi) davranış testləri.
// Əhatə: K-2 (chat mesajları), K-5 (follows), K-8 (reputasiya sayğacları),
// K-9 (pinboxes), + reviews/usernames/birthdayMatches/venues.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  arrayRemove,
  arrayUnion,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import { createTestEnv, userFixture, venueFixture } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

before(async () => {
  testEnv = await createTestEnv();
});

after(async () => {
  await testEnv.cleanup();
});

async function seed(fn: (db: ReturnType<RulesTestEnvironment["unauthenticatedContext"]>["firestore"]) => Promise<void>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(() => ctx.firestore()));
}

// ---------------------------------------------------------------------------
// K-2 — chat messages (8 hal)
// ---------------------------------------------------------------------------
describe("Prompt 2 / K-2 — chat mesajları", () => {
  const uidA = "k2-uidA";
  const uidB = "k2-uidB";
  const chatId = `${uidA}_${uidB}`;
  const messagePath = ["chats", chatId, "messages"] as const;

  before(async () => {
    await seed(async (fs) =>
      setDoc(doc(fs(), "chats", chatId), { participants: [uidA, uidB], initiatorId: uidA, status: "accepted" }),
    );
  });

  /** Hər mutasiya edən test ÖZ, təmiz mesaj sənədini alır (testlər
   * bir-birindən asılı olmasın deyə — paylaşılan sənəd üzərində
   * ardıcıl mutasiyalar əvvəlki testin vəziyyətini sonrakı testə sızdıra
   * bilər, məhz bu səbəbdən `deletedFor` testlərindən biri ilk cəhddə
   * yanlış keçmişdi).
   *
   * `deletedFor` PARAMETRİ VERİLMƏSƏ, sahə ÜMUMİYYƏTLƏ YAZILMIR — bu,
   * real `FirebaseChatRepository._sendMessage`-in yaratdığı mesajın
   * DƏQİQ EYNİSİDİR (o da bu sahəni heç vaxt başlanğıcda yazmır). Post-
   * launch QA tapıntısı: köhnə versiya bu funksiyada HƏMİŞƏ `deletedFor:
   * []`-i əvvəlcədən yazırdı, ona görə də rules-dakı `resource.data.
   * deletedFor`-un sənəddə sahə YOXDURSA partladığı boşluq heç vaxt
   * sınanmamışdı — istifadəçinin real şikayəti məhz bunun nəticəsi idi. */
  async function seedFreshMessage(deletedFor?: string[]): Promise<string> {
    let messageId = "";
    await seed(async (fs) => {
      const ref = doc(collection(fs(), ...messagePath));
      messageId = ref.id;
      await setDoc(ref, {
        senderId: uidA,
        receiverId: uidB,
        type: "text",
        text: "salam",
        sentAt: new Date(),
        ...(deletedFor !== undefined ? { deletedFor } : {}),
      });
    });
    return messageId;
  }

  test("deliveredAt/readAt yenilənməsi iştirakçı tərəfindən keçir", async () => {
    const messageId = await seedFreshMessage();
    const db = testEnv.authenticatedContext(uidB).firestore();
    await assertSucceeds(
      updateDoc(doc(db, ...messagePath, messageId), { deliveredAt: new Date(), readAt: new Date() }),
    );
  });

  test("text sahəsinin dəyişdirilməsi rədd edilir", async () => {
    const messageId = await seedFreshMessage();
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { text: "dəyişdirildi" }));
  });

  test("senderId sahəsinin dəyişdirilməsi rədd edilir", async () => {
    const messageId = await seedFreshMessage();
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { senderId: uidB }));
  });

  test("mediaUrl sahəsinin dəyişdirilməsi rədd edilir", async () => {
    const messageId = await seedFreshMessage();
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { mediaUrl: "https://evil.example/x.jpg" }));
  });

  // Post-launch QA — bu, əsl istifadəçi şikayətinin dəqiq təkrarıdır:
  // `deletedFor` sahəsi HEÇ OLMAYAN (real client-in yaratdığı kimi) bir
  // mesajda "özün üçün sil" göndərənin ÖZ mesajında da, DİGƏR
  // iştirakçının mesajında da işləməli idi — hər ikisi eyni rule-dan
  // keçir, sender/receiver fərqi yoxdur.
  test("deletedFor sahəsi olmayan mesajda göndərənin ÖZÜ öz uid-ini əlavə edə bilir (sahə yoxdursa)", async () => {
    const messageId = await seedFreshMessage(); // sahə YAZILMIR — real client kimi
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertSucceeds(updateDoc(doc(db, ...messagePath, messageId), { deletedFor: arrayUnion(uidA) }));
  });

  test("deletedFor sahəsi olmayan BAŞQASININ mesajında alıcı öz uid-ini əlavə edə bilir (sahə yoxdursa — əsl şikayət)", async () => {
    const messageId = await seedFreshMessage(); // sahə YAZILMIR — real client kimi
    const db = testEnv.authenticatedContext(uidB).firestore();
    await assertSucceeds(updateDoc(doc(db, ...messagePath, messageId), { deletedFor: arrayUnion(uidB) }));
  });

  test("deletedFor sahəsi ARTIQ MÖVCUDDURSA (əvvəlki davranış) öz uid-ini əlavə etmək yenə keçir", async () => {
    const messageId = await seedFreshMessage([]); // sahə açıq şəkildə yazılır, boş massiv
    const db = testEnv.authenticatedContext(uidB).firestore();
    await assertSucceeds(updateDoc(doc(db, ...messagePath, messageId), { deletedFor: arrayUnion(uidB) }));
  });

  test("deletedFor-a başqasının uid-ini əlavə etmək rədd edilir", async () => {
    const messageId = await seedFreshMessage(); // sahə yoxdur — uidB hələ orada deyil
    const db = testEnv.authenticatedContext(uidA).firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { deletedFor: arrayUnion(uidB) }));
  });

  test("deletedFor-dan mövcud dəyəri silmək rədd edilir", async () => {
    const messageId = await seedFreshMessage([uidB]); // uidB artıq deletedFor-dadır
    const db = testEnv.authenticatedContext(uidB).firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { deletedFor: arrayRemove(uidB) }));
  });

  test("iştirakçı olmayan şəxsin update cəhdi rədd edilir", async () => {
    const messageId = await seedFreshMessage();
    const db = testEnv.authenticatedContext("k2-outsider").firestore();
    await assertFails(updateDoc(doc(db, ...messagePath, messageId), { deliveredAt: new Date() }));
  });
});

// ---------------------------------------------------------------------------
// K-5 — follows (6 hal)
// ---------------------------------------------------------------------------
describe("Prompt 2 / K-5 — follows create", () => {
  before(async () => {
    await seed(async (fs) => {
      const db = fs();
      await setDoc(doc(db, "users", "k5-public-followee"), userFixture("k5-public-followee", { accountPrivacy: "public" }));
      await setDoc(doc(db, "users", "k5-private-followee"), userFixture("k5-private-followee", { accountPrivacy: "private" }));
      const { accountPrivacy: _omit, ...noPrivacy } = userFixture("k5-no-privacy-field");
      await setDoc(doc(db, "users", "k5-no-privacy-field"), noPrivacy);
    });
  });

  test("public hesaba accepted status ilə follow yaratmaq keçir", async () => {
    const follower = "k5-follower-1";
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertSucceeds(
      setDoc(doc(db, "follows", `${follower}_k5-public-followee`), {
        followerId: follower,
        followeeId: "k5-public-followee",
        status: "accepted",
        createdAt: new Date(),
      }),
    );
  });

  test("private hesaba accepted status ilə follow yaratmaq rədd edilir", async () => {
    const follower = "k5-follower-2";
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertFails(
      setDoc(doc(db, "follows", `${follower}_k5-private-followee`), {
        followerId: follower,
        followeeId: "k5-private-followee",
        status: "accepted",
        createdAt: new Date(),
      }),
    );
  });

  test("private hesaba pending status ilə follow yaratmaq keçir", async () => {
    const follower = "k5-follower-3";
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertSucceeds(
      setDoc(doc(db, "follows", `${follower}_k5-private-followee`), {
        followerId: follower,
        followeeId: "k5-private-followee",
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("accountPrivacy sahəsi olmayan hesaba accepted keçir (default public)", async () => {
    const follower = "k5-follower-4";
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertSucceeds(
      setDoc(doc(db, "follows", `${follower}_k5-no-privacy-field`), {
        followerId: follower,
        followeeId: "k5-no-privacy-field",
        status: "accepted",
        createdAt: new Date(),
      }),
    );
  });

  test("pending → accepted keçidi followee tərəfindən keçir", async () => {
    const follower = "k5-follower-5";
    const followId = `${follower}_k5-private-followee`;
    await seed(async (fs) =>
      setDoc(doc(fs(), "follows", followId), {
        followerId: follower,
        followeeId: "k5-private-followee",
        status: "pending",
        createdAt: new Date(),
      }),
    );
    const db = testEnv.authenticatedContext("k5-private-followee").firestore();
    await assertSucceeds(updateDoc(doc(db, "follows", followId), { status: "accepted" }));
  });

  test("eyni keçid follower tərəfindən edilərsə rədd edilir", async () => {
    const follower = "k5-follower-6";
    const followId = `${follower}_k5-private-followee`;
    await seed(async (fs) =>
      setDoc(doc(fs(), "follows", followId), {
        followerId: follower,
        followeeId: "k5-private-followee",
        status: "pending",
        createdAt: new Date(),
      }),
    );
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertFails(updateDoc(doc(db, "follows", followId), { status: "accepted" }));
  });
});

// ---------------------------------------------------------------------------
// K-8 — reputasiya sayğacları (5 hal)
// ---------------------------------------------------------------------------
describe("Prompt 2 / K-8 — users reputasiya sayğacları", () => {
  /** Hər test ÖZ, məlum başlanğıc `reportedCount` dəyərli hədəf
   * istifadəçisini alır — paylaşılan hədəf + geri-oxuma yerinə (əvvəlki
   * versiyada `withSecurityRulesDisabled`-in geri qaytardığı dəyəri
   * `undefined` olaraq aşkar etdi, SDK bu callback-in nəticəsini
   * ötürmür) sadə, sabit ədədlərlə işləyir. */
  async function seedTarget(reportedCount: number): Promise<string> {
    const uid = `k8-target-${reportedCount}-${Math.random().toString(36).slice(2, 8)}`;
    await seed(async (fs) => setDoc(doc(fs(), "users", uid), userFixture(uid, { reportedCount })));
    return uid;
  }

  test("reportedCount +1, başqa istifadəçi tərəfindən keçir", async () => {
    const target = await seedTarget(0);
    const db = testEnv.authenticatedContext("k8-reporter-1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users", target), { reportedCount: 1 }));
  });

  test("starCount dəyişikliyi rədd edilir", async () => {
    const target = await seedTarget(0);
    const db = testEnv.authenticatedContext("k8-reporter-2").firestore();
    await assertFails(updateDoc(doc(db, "users", target), { starCount: 5 }));
  });

  test("reportedCount +1 və starCount:999 eyni yazıda rədd edilir (əvvəlki || qüsurunun testi)", async () => {
    const target = await seedTarget(5);
    const db = testEnv.authenticatedContext("k8-reporter-3").firestore();
    await assertFails(updateDoc(doc(db, "users", target), { reportedCount: 6, starCount: 999 }));
  });

  test("reportedCount +2 (və ya azaldılması) rədd edilir", async () => {
    const target = await seedTarget(5);
    const db = testEnv.authenticatedContext("k8-reporter-4").firestore();
    await assertFails(updateDoc(doc(db, "users", target), { reportedCount: 7 }));
  });

  test("sahibin öz sayğacını dəyişməsi rədd edilir (Düzəliş Prompt 12 tapıntısı, sonra düzəldilib — reportedCount touchesLockedUserFields()-ə əlavə olundu)", async () => {
    const target = await seedTarget(5);
    const db = testEnv.authenticatedContext(target).firestore();
    await assertFails(updateDoc(doc(db, "users", target), { reportedCount: 6 }));
  });
});

// ---------------------------------------------------------------------------
// K-9 — pinboxes (3 hal)
// ---------------------------------------------------------------------------
describe("Prompt 2 / K-9 — pinboxes venue sahibliyi", () => {
  const owner = "k9-owner";
  const stranger = "k9-stranger";
  const venueId = "k9-venue";

  before(async () => {
    await seed(async (fs) => {
      const db = fs();
      await setDoc(doc(db, "users", owner), userFixture(owner));
      await setDoc(doc(db, "users", stranger), userFixture(stranger));
      await setDoc(doc(db, "venues", venueId), venueFixture(owner));
    });
  });

  test("öz venue-si ilə pinbox yaratmaq keçir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertSucceeds(
      setDoc(doc(db, "pinboxes", "k9-pinbox-own"), {
        ownerId: owner,
        venueId,
        status: "pending",
        stockTotal: 10,
        stockRemaining: 10,
        title: "Test",
      }),
    );
  });

  test("başqasının venue-si ilə pinbox yaratmaq rədd edilir", async () => {
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertFails(
      setDoc(doc(db, "pinboxes", "k9-pinbox-stranger"), {
        ownerId: stranger,
        venueId,
        status: "pending",
        stockTotal: 10,
        stockRemaining: 10,
        title: "Test",
      }),
    );
  });

  test("update-də venueId dəyişikliyi rədd edilir", async () => {
    const otherVenueId = "k9-other-venue";
    await seed(async (fs) => setDoc(doc(fs(), "venues", otherVenueId), venueFixture(owner)));
    const pinboxId = "k9-pinbox-for-update";
    await seed(async (fs) =>
      setDoc(doc(fs(), "pinboxes", pinboxId), {
        ownerId: owner,
        venueId,
        status: "pending",
        stockTotal: 10,
        stockRemaining: 10,
        title: "Test",
      }),
    );
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "pinboxes", pinboxId), { venueId: otherVenueId }));
  });
});

// ---------------------------------------------------------------------------
// Qalanlar — reviews / usernames / birthdayMatches / venues (8 hal)
// ---------------------------------------------------------------------------
describe("Prompt 2 — reviews read (INFRA-8)", () => {
  const venueId = "qalan-review-venue";
  const owner = "qalan-review-owner";
  const reviewer = "qalan-reviewer";
  const reviewId = `${venueId}_${reviewer}`;

  before(async () => {
    await seed(async (fs) => {
      const db = fs();
      await setDoc(doc(db, "venues", venueId), venueFixture(owner));
      await setDoc(doc(db, "reviews", reviewId), {
        venueId,
        userId: reviewer,
        rating: 5,
        comment: "Əla",
        createdAt: new Date(),
      });
    });
  });

  test("imzalanmamış istifadəçi review oxuya bilmir", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "reviews", reviewId)));
  });

  test("imzalanmış istifadəçi review oxuya bilir", async () => {
    const db = testEnv.authenticatedContext("qalan-reader").firestore();
    await assertSucceeds(getDoc(doc(db, "reviews", reviewId)));
  });
});

describe("Prompt 2 — usernames get/list (Quick Win 1)", () => {
  before(async () => {
    await seed(async (fs) => setDoc(doc(fs(), "usernames", "qalan-username"), { uid: "qalan-username-owner", createdAt: new Date() }));
  });

  test("imzalanmamış istifadəçi usernames list edə bilmir", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDocs(query(collection(db, "usernames"), where("uid", "==", "qalan-username-owner"))));
  });

  test("imzalanmamış istifadəçi tək username get edə bilir (deep-link üçün QƏSDƏN açıq — bax firestore.rules-un öz şərhi)", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "usernames", "qalan-username")));
  });
});

describe("Prompt 2 — birthdayMatches get (INFRA-11)", () => {
  const ownVenueId = "qalan-bday-own-venue";
  const otherVenueId = "qalan-bday-other-venue";
  const owner = "qalan-bday-owner";
  const otherOwner = "qalan-bday-other-owner";
  const matchId = `2026-01-01_${ownVenueId}`;

  before(async () => {
    await seed(async (fs) => {
      const db = fs();
      await setDoc(doc(db, "venues", ownVenueId), venueFixture(owner));
      await setDoc(doc(db, "venues", otherVenueId), venueFixture(otherOwner));
      await setDoc(doc(db, "birthdayMatches", matchId), { venueId: ownVenueId, matchedUserIds: [] });
    });
  });

  test("öz venue-sinin birthdayMatches sənədini oxumaq keçir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertSucceeds(getDoc(doc(db, "birthdayMatches", matchId)));
  });

  test("başqasının venue-sinin birthdayMatches sənədini oxumaq rədd edilir", async () => {
    const db = testEnv.authenticatedContext(otherOwner).firestore();
    await assertFails(getDoc(doc(db, "birthdayMatches", matchId)));
  });
});

describe("Prompt 2 — venues.verified/gallery kilidi (C#61)", () => {
  const owner = "qalan-venue-owner";
  const venueId = "qalan-locked-venue";

  before(async () => {
    await seed(async (fs) => setDoc(doc(fs(), "venues", venueId), venueFixture(owner)));
  });

  test("verified sahəsinin sahib tərəfindən dəyişdirilməsi rədd edilir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "venues", venueId), { verified: true }));
  });

  test("gallery sahəsinin sahib tərəfindən dəyişdirilməsi rədd edilir", async () => {
    const db = testEnv.authenticatedContext(owner).firestore();
    await assertFails(updateDoc(doc(db, "venues", venueId), { gallery: ["https://example.com/1.jpg"] }));
  });
});

// Say: 30 test (K-2: 8, K-5: 6, K-8: 5, K-9: 3, Qalanlar: 8 — promptun
// "Qalanlar" bölməsindəki 5 bənd, hər biri 1-2 halı əhatə etdiyi üçün 8
// testə açılıb: reviews×2, usernames×2, birthdayMatches×2, venues×2).
