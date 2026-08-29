// Düzəliş Prompt 5 — Blok mexanizminin server tərəfə köçürülməsi (K-3,
// RT-5, RT-6, RT-14) davranış testləri. Əhatə: chats/messages/calls
// create+update-də iki-istiqamətli blok yoxlaması, `whoCanMessageMe:
// followersOnly`-nin server-side tətbiqi, rədd edilmiş söhbətə mesaj
// yazılmaması (RT-5 — eyni-tranzaksiya `exists()` görünürlüyü empirik
// yoxlanılır), və `users/{uid}` profil oxumasının blok-aware olması.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, runTransaction, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";
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

// ---------------------------------------------------------------------------
// RT-5 — KRİTİK EMPİRİK TEST (əvvəlcə işlədilir, tarixi uğursuzluq
// presedenti var — istifadəçinin öz tələbi: bu, blok işini əngəlləməsin).
// ---------------------------------------------------------------------------
describe("RT-5 (empirik) — eyni-tranzaksiyada çat+ilk mesaj yaradılması", () => {
  test("brand-new çatın İLK mesajı (tranzaksiyada çat+mesaj birgə yaradılır) keçir", async () => {
    const a = "p5-rt5-a";
    const b = "p5-rt5-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });

    const chatId = chatIdFor(a, b);
    const db = testEnv.authenticatedContext(a).firestore();

    // FirebaseChatRepository._sendMessage-in ÖZÜ ilə EYNİ naxış: bir
    // tranzaksiyada tx.get(chatRef) + tx.set(chatRef,...) + tx.set(msgRef,...).
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const chatRef = doc(db, "chats", chatId);
        const chatSnap = await tx.get(chatRef);
        if (!chatSnap.exists()) {
          tx.set(chatRef, {
            participants: [a, b].sort(),
            initiatorId: a,
            status: "pending",
            lastMessage: "salam",
            lastMessageType: "text",
            lastMessageAt: serverTimestamp(),
            lastMessageSenderId: a,
            unreadCount: { [b]: 1, [a]: 0 },
            createdAt: serverTimestamp(),
          });
        }
        const msgRef = doc(db, "chats", chatId, "messages", "msg1");
        tx.set(msgRef, {
          senderId: a,
          receiverId: b,
          type: "text",
          text: "salam",
          sentAt: serverTimestamp(),
        });
      }),
    );
  });

  test("'declined' çata YENİ mesaj yazmaq rədd edilir", async () => {
    const a = "p5-rt5-declined-a";
    const b = "p5-rt5-declined-b";
    const chatId = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", chatId), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "declined",
        createdAt: new Date(),
      });
    });

    const db = testEnv.authenticatedContext(a).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatId, "messages", "msg2"), {
        senderId: a,
        receiverId: b,
        type: "text",
        text: "yenə yazıram",
        sentAt: new Date(),
      }),
    );
  });

  test("'accepted' çata mesaj yazmaq keçir (regression)", async () => {
    const a = "p5-rt5-accepted-a";
    const b = "p5-rt5-accepted-b";
    const chatId = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", chatId), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "accepted",
        createdAt: new Date(),
      });
    });

    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatId, "messages", "msg3"), {
        senderId: a,
        receiverId: b,
        type: "text",
        text: "salam",
        sentAt: new Date(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// K-3 — blok, iki istiqamətli, chats/messages/calls
// ---------------------------------------------------------------------------
describe("K-3 — blok: chats create", () => {
  test("A B-ni bloklayıb — B çat aça bilmir", async () => {
    const a = "p5-block-chatcreate-a";
    const b = "p5-block-chatcreate-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, b].sort(),
        initiatorId: b,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("B A-nı bloklayıb (əks istiqamət) — A çat aça bilmir", async () => {
    const a = "p5-block-chatcreate2-a";
    const b = "p5-block-chatcreate2-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b, { blockedUsers: [a] }));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("blok yoxdursa çat yaratmaq keçir (regression)", async () => {
    const a = "p5-block-chatcreate3-a";
    const b = "p5-block-chatcreate3-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatIdFor(a, b)), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });
});

describe("K-3 — blok: mövcud (accepted) çatda mesaj", () => {
  test("mövcud accepted çatda sonradan blok olsa, mesaj yazmaq rədd edilir (ən adi ssenari)", async () => {
    const a = "p5-block-midchat-a";
    const b = "p5-block-midchat-b";
    const chatId = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b, { blockedUsers: [a] })); // b sonradan a-nı bloklayır
      await setDoc(doc(fs, "chats", chatId), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "accepted",
        createdAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatId, "messages", "msgBlocked"), {
        senderId: a,
        receiverId: b,
        type: "text",
        text: "hey",
        sentAt: new Date(),
      }),
    );
  });
});

describe("K-3 — blok: chats accept/decline", () => {
  test("bloklanmış cütdə pending sorğunu accepted-ə çevirmək rədd edilir", async () => {
    const a = "p5-block-accept-a";
    const b = "p5-block-accept-b";
    const chatId = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", chatId), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
        createdAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertFails(updateDoc(doc(db, "chats", chatId), { status: "accepted" }));
  });

  test("bloklanmış cütdə declined-ə çevirmək YENƏ DƏ keçir (rədd etmək qapını bağlayır, açmır)", async () => {
    const a = "p5-block-decline-a";
    const b = "p5-block-decline-b";
    const chatId = chatIdFor(a, b);
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
      await setDoc(doc(fs, "chats", chatId), {
        participants: [a, b].sort(),
        initiatorId: a,
        status: "pending",
        createdAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertSucceeds(updateDoc(doc(db, "chats", chatId), { status: "declined" }));
  });
});

describe("K-3/RT-14 — blok: calls create", () => {
  test("A B-ni bloklayıb — B zəng edə bilmir", async () => {
    const a = "p5-block-call-a";
    const b = "p5-block-call-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertFails(
      setDoc(doc(db, "calls", "p5-call-1"), {
        callerId: b,
        receiverId: a,
        participants: [b, a],
        type: "audio",
        status: "ringing",
        createdAt: new Date(),
      }),
    );
  });

  test("blok yoxdursa zəng yaratmaq keçir (regression)", async () => {
    const a = "p5-block-call2-a";
    const b = "p5-block-call2-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertSucceeds(
      setDoc(doc(db, "calls", "p5-call-2"), {
        callerId: b,
        receiverId: a,
        participants: [b, a],
        type: "audio",
        status: "ringing",
        createdAt: new Date(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// RT-6 — whoCanMessageMe: followersOnly server-side
// ---------------------------------------------------------------------------
describe("RT-6 — whoCanMessageMe: followersOnly", () => {
  test("followersOnly + izləyici yoxdur — çat yaratmaq rədd edilir", async () => {
    const owner = "p5-rt6-owner";
    const stranger = "p5-rt6-stranger";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner, { whoCanMessageMe: "followersOnly" }));
      await setDoc(doc(fs, "users", stranger), userFixture(stranger));
    });
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertFails(
      setDoc(doc(db, "chats", chatIdFor(owner, stranger)), {
        participants: [owner, stranger].sort(),
        initiatorId: stranger,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("followersOnly + göndərən izləyicidir (owner-ə tərəf accepted follow) — keçir", async () => {
    const owner = "p5-rt6-owner2";
    const follower = "p5-rt6-follower2";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner, { whoCanMessageMe: "followersOnly" }));
      await setDoc(doc(fs, "users", follower), userFixture(follower));
      await setDoc(doc(fs, "follows", `${follower}_${owner}`), { followerId: follower, followeeId: owner, status: "accepted" });
    });
    const db = testEnv.authenticatedContext(follower).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatIdFor(owner, follower)), {
        participants: [owner, follower].sort(),
        initiatorId: follower,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("followersOnly + owner göndərənin izləyicisidir (əks istiqamət) — keçir", async () => {
    const owner = "p5-rt6-owner3";
    const other = "p5-rt6-other3";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner, { whoCanMessageMe: "followersOnly" }));
      await setDoc(doc(fs, "users", other), userFixture(other));
      await setDoc(doc(fs, "follows", `${owner}_${other}`), { followerId: owner, followeeId: other, status: "accepted" });
    });
    const db = testEnv.authenticatedContext(other).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatIdFor(owner, other)), {
        participants: [owner, other].sort(),
        initiatorId: other,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });

  test("everyone (defolt) — istənilən kəs çat aça bilir (regression)", async () => {
    const owner = "p5-rt6-owner4";
    const stranger = "p5-rt6-stranger4";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", owner), userFixture(owner));
      await setDoc(doc(fs, "users", stranger), userFixture(stranger));
    });
    const db = testEnv.authenticatedContext(stranger).firestore();
    await assertSucceeds(
      setDoc(doc(db, "chats", chatIdFor(owner, stranger)), {
        participants: [owner, stranger].sort(),
        initiatorId: stranger,
        status: "pending",
        createdAt: new Date(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// K-3 — profil oxuma bloku (users/{uid} allow get)
// ---------------------------------------------------------------------------
// Düzəliş Prompt 5-in dəqiq tələbi bir-istiqamətlidir: BLOKLANAN
// tərəf BLOKLAYANIN profilini görməməlidir — əksi YOX. Simmetrik
// olsaydı, `blocked_users_screen.dart`-ın öz "blokdan çıxart"
// siyahısı hər kimi bloklamış olsan da adını/fotosunu göstərə
// bilməzdi (hamısı "İstifadəçi" görünərdi, hansının kim olduğunu
// ayırd etmək mümkün olmazdı).
describe("K-3 — users/{uid} get: bir-istiqamətli (yalnız bloklanan tərəf görə bilmir)", () => {
  test("A B-ni bloklayıb — B (bloklanan) A-nın (bloklayanın) profilini oxuya bilmir", async () => {
    const a = "p5-profile-a";
    const b = "p5-profile-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertFails(getDoc(doc(db, "users", a)));
  });

  test("A B-ni bloklayıb — A (bloklayan) ÖZÜ B-nin profilini YENƏ DƏ oxuya bilir (asimmetriya)", async () => {
    const a = "p5-profile-asym-a";
    const b = "p5-profile-asym-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a, { blockedUsers: [b] }));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(getDoc(doc(db, "users", b)));
  });

  test("B A-nı bloklayıb (əks istiqamət) — A (bloklanan) B-nin (bloklayanın) profilini oxuya bilmir", async () => {
    const a = "p5-profile2-a";
    const b = "p5-profile2-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b, { blockedUsers: [a] }));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertFails(getDoc(doc(db, "users", b)));
  });

  test("blok yoxdursa profil oxumaq keçir (regression)", async () => {
    const a = "p5-profile3-a";
    const b = "p5-profile3-b";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
      await setDoc(doc(fs, "users", b), userFixture(b));
    });
    const db = testEnv.authenticatedContext(b).firestore();
    await assertSucceeds(getDoc(doc(db, "users", a)));
  });

  test("öz profilini oxumaq həmişə keçir (blokedUsers boş olsa belə)", async () => {
    const a = "p5-profile4-a";
    await seed(async (fs) => {
      await setDoc(doc(fs, "users", a), userFixture(a));
    });
    const db = testEnv.authenticatedContext(a).firestore();
    await assertSucceeds(getDoc(doc(db, "users", a)));
  });
});
