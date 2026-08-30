/**
 * P0 / C-1 — unit tests for the deterministic chat-media path
 * derivation (`functions/src/chat-media.ts`).
 *
 * Unlike every other file in this directory these are NOT rules tests
 * and need no emulator — `chatMediaPathForMessage` is a pure function,
 * imported directly. It lives in this suite anyway so `npm --prefix
 * tests/rules test` stays the single command that proves the security
 * boundary, rather than adding a second test runner to `functions/`
 * (which would mean a new dependency there).
 *
 * These are the negative tests the audit's C-1 finding demanded:
 * the whole point is that a client-supplied `mediaUrl` can no longer
 * influence WHICH object gets deleted.
 */
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { chatMediaPathForMessage, resizedVariantPath } from "../../functions/src/chat-media";
import { resizedVariantPath as adminResizedVariantPath } from "../../admin-panel/src/lib/chat-media-path";

const CHAT = "uidA_uidB";
const MSG = "msg123";

test("C-1: image message resolves to the deterministic chat_photos path", () => {
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, {
      type: "image",
      senderId: "uidA",
      mediaUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/chat_photos%2FuidA_uidB%2FuidA%2Fmsg123.jpg?alt=media",
    }),
    "chat_photos/uidA_uidB/uidA/msg123.jpg",
  );
});

test("C-1: video and audio resolve to their own folders/extensions", () => {
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, { type: "video", senderId: "uidA", mediaUrl: "https://x/o/y" }),
    "chat_videos/uidA_uidB/uidA/msg123.mp4",
  );
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, { type: "audio", senderId: "uidB", mediaUrl: "https://x/o/y" }),
    "chat_audio/uidA_uidB/uidB/msg123.m4a",
  );
});

test("C-1: a hostile mediaUrl cannot redirect the delete to another user's profile photo", () => {
  // The exact attack from the audit: a crafted `mediaUrl` pointing at
  // someone else's object. The derived path must ignore it entirely.
  const path = chatMediaPathForMessage(CHAT, MSG, {
    type: "image",
    senderId: "uidA",
    mediaUrl: "x/o/profile_photos%2FVICTIM_UID%2Fprofile.jpg",
  });
  assert.equal(path, "chat_photos/uidA_uidB/uidA/msg123.jpg");
  assert.ok(!path!.includes("profile_photos"));
  assert.ok(!path!.includes("VICTIM_UID"));
});

test("C-1: a hostile mediaUrl cannot reach identity-verification documents", () => {
  const path = chatMediaPathForMessage(CHAT, MSG, {
    type: "image",
    senderId: "uidA",
    mediaUrl: "https://evil.test/o/identity_verifications%2FVICTIM%2FREQ%2Fselfie.jpg",
  });
  assert.ok(!path!.includes("identity_verifications"));
  assert.equal(path, "chat_photos/uidA_uidB/uidA/msg123.jpg");
});

test("C-1/A-2: a shared-post message resolves to null — the original post media is never touched", () => {
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, {
      type: "post",
      senderId: "uidA",
      postId: "post1",
      mediaUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/posts%2FuidC%2Fclip.mp4?alt=media",
    }),
    null,
  );
});

test("C-1: text messages and media-less messages resolve to null", () => {
  assert.equal(chatMediaPathForMessage(CHAT, MSG, { type: "text", senderId: "uidA", text: "salam" }), null);
  assert.equal(chatMediaPathForMessage(CHAT, MSG, { type: "image", senderId: "uidA" }), null);
  assert.equal(chatMediaPathForMessage(CHAT, MSG, { type: "image", senderId: "uidA", mediaUrl: "" }), null);
});

test("C-1: an unknown/new message type resolves to null rather than guessing a folder", () => {
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, { type: "sticker", senderId: "uidA", mediaUrl: "https://x/o/y" }),
    null,
  );
  assert.equal(chatMediaPathForMessage(CHAT, MSG, { senderId: "uidA", mediaUrl: "https://x/o/y" }), null);
});

test("C-1: a missing or non-string senderId resolves to null", () => {
  assert.equal(chatMediaPathForMessage(CHAT, MSG, { type: "image", mediaUrl: "https://x/o/y" }), null);
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, { type: "image", senderId: 42, mediaUrl: "https://x/o/y" }),
    null,
  );
});

test("C-1: a separator in any id component resolves to null (no prefix escape)", () => {
  assert.equal(
    chatMediaPathForMessage("a/../b", MSG, { type: "image", senderId: "uidA", mediaUrl: "https://x/o/y" }),
    null,
  );
  assert.equal(
    chatMediaPathForMessage(CHAT, "m/../x", { type: "image", senderId: "uidA", mediaUrl: "https://x/o/y" }),
    null,
  );
  assert.equal(
    chatMediaPathForMessage(CHAT, MSG, { type: "image", senderId: "u/../v", mediaUrl: "https://x/o/y" }),
    null,
  );
});

test("C-1: derived path always stays inside a chat-media folder for this exact chat", () => {
  // Property-style sweep over hostile inputs: whatever the client puts
  // in `mediaUrl`, the result is either null or this chat's own prefix.
  const hostile = [
    "x/o/profile_photos%2Fv%2Fp.jpg",
    "x/o/venue_photos%2Fv%2Fv.jpg",
    "x/o/posts%2Fv%2Fp.mp4",
    "x/o/identity_verifications%2Fv%2Fr%2Fs.jpg",
    "x/o/chat_photos%2FOTHER_CHAT%2FOTHER%2Fm.jpg",
    "/o/",
    "https://firebasestorage.googleapis.com/v0/b/x/o/..%2F..%2Fetc?alt=media",
  ];
  for (const mediaUrl of hostile) {
    for (const type of ["image", "video", "audio"]) {
      const path = chatMediaPathForMessage(CHAT, MSG, { type, senderId: "uidA", mediaUrl });
      assert.ok(path !== null, `expected a derived path for type=${type}`);
      assert.match(path!, new RegExp(`^chat_(photos|videos|audio)/${CHAT}/uidA/${MSG}\\.(jpg|mp4|m4a)$`));
    }
  }
});

// ---------------------------------------------------------------------------
// P0 / H-1 (a) — məsafə səbətləməsi. `bucketDistanceMeters` `index.ts`-də
// yaşayır (firebase-admin idxal edir, buradan çağırıla bilməz), ona görə
// eyni düstur burada təkrarlanır: test düsturun ÖZÜNÜ, yəni "açıqlanan
// dəqiqlik marker şəbəkəsindən incə ola bilməz" invariantını qoruyur.
// ---------------------------------------------------------------------------
const BUCKET = 100;
const bucketDistanceMeters = (m: number) => Math.max(BUCKET, Math.round(m / BUCKET) * BUCKET);

test("H-1: məsafə 100 m-in tam qatlarına yuvarlaqlanır", () => {
  assert.equal(bucketDistanceMeters(247), 200);
  assert.equal(bucketDistanceMeters(251), 300);
  assert.equal(bucketDistanceMeters(1449), 1400);
});

test("H-1: 100 m-dən yaxın hər şey 100 m kimi göstərilir (0 m heç vaxt qaytarılmır)", () => {
  for (const m of [0, 0.5, 12, 49, 50, 99]) {
    assert.equal(bucketDistanceMeters(m), 100, `${m} m üçün`);
  }
});

test("H-1: eyni əsl məsafə həmişə eyni səbətə düşür (averaging hücumu işləmir)", () => {
  const truth = 372.4816;
  const results = new Set(Array.from({ length: 50 }, () => bucketDistanceMeters(truth)));
  assert.equal(results.size, 1);
});

test("H-1: trilaterasiya dəqiqliyi marker şəbəkəsindən incə deyil", () => {
  // Üç fərqli mövqedən ölçülən dəqiq məsafələr eyni səbətə düşdüyü
  // müddətcə hücumçu 100 m-dən dəqiq nəticə ala bilmir.
  const exact = [372.4816, 401.2, 349.9];
  const buckets = exact.map(bucketDistanceMeters);
  for (const b of buckets) assert.equal(b % BUCKET, 0);
  assert.ok(Math.min(...buckets) >= BUCKET);
});

// ---------------------------------------------------------------------------
// P0 / H-4 — "hər iki tərəf gizlədib" predikatı. Bu, sənədin FİZİKİ
// silinməsi qərarının dayandığı yeganə şərtdir, ona görə ayrıca test
// olunur: səhv `true` iki nəfər üçün geri qaytarılmaz data itkisidir.
// ---------------------------------------------------------------------------
import { isChatHiddenByEveryone } from "../../functions/src/chat-media";

test("H-4: yalnız hər İKİ iştirakçı gizlədəndə true", () => {
  const p = ["a", "b"];
  assert.equal(isChatHiddenByEveryone(p, { a: true, b: true }), true);
  assert.equal(isChatHiddenByEveryone(p, { a: true }), false);
  assert.equal(isChatHiddenByEveryone(p, { a: true, b: false }), false);
  assert.equal(isChatHiddenByEveryone(p, {}), false);
});

test("H-4: yalnız `true` sayılır — truthy dəyərlər kifayət etmir", () => {
  const p = ["a", "b"];
  assert.equal(isChatHiddenByEveryone(p, { a: true, b: "true" }), false);
  assert.equal(isChatHiddenByEveryone(p, { a: true, b: 1 }), false);
});

test("H-4: pozuq və ya boş giriş HEÇ VAXT silməyə səbəb olmur", () => {
  assert.equal(isChatHiddenByEveryone([], {}), false);
  assert.equal(isChatHiddenByEveryone(undefined, { a: true }), false);
  assert.equal(isChatHiddenByEveryone(["a"], null), false);
  assert.equal(isChatHiddenByEveryone(["a"], undefined), false);
  assert.equal(isChatHiddenByEveryone(["a"], "yes"), false);
  assert.equal(isChatHiddenByEveryone([null, "b"], { b: true }), false);
});

test("H-4: əlavə uid-lər map-də olsa da yalnız iştirakçılar sayılır", () => {
  assert.equal(isChatHiddenByEveryone(["a", "b"], { a: true, b: true, c: false }), true);
});

// ---------------------------------------------------------------------------
// F-1 — `admin-panel` öz `deleteUserAccountPermanently`-sini ayrıca
// implementasiya edir (iki müstəqil Node layihəsi, ortaq paket yoxdur)
// və orada eyni C-1 zəifliyi müstəqil şəkildə yenidən yaranmışdı:
// client-in yazdığı `mediaUrl` Admin SDK-nın silmə çağırışına
// ötürülürdü. İndi hər iki tərəf eyni deterministik yol məntiqini
// istifadə edir.
//
// Bu testlərin məqsədi TƏKRARLANMANIN ÖZÜNÜ qorumaqdır: dublikat
// təhlükəsizlik sərhədi yalnız o halda təhlükəsizdir ki, iki nüsxənin
// bir-birindən uzaqlaşması AŞKARLANA bilsin.
// ---------------------------------------------------------------------------
import { chatMediaPathForMessage as adminPanelPath } from "../../admin-panel/src/lib/chat-media-path";

test("F-1: admin panel nüsxəsi düşmən mediaUrl-u yolu dəyişməyə buraxmır", () => {
  const path = adminPanelPath("uidA_uidB", "msg1", {
    type: "image",
    senderId: "uidA",
    mediaUrl: "x/o/identity_verifications%2FVICTIM%2FREQ%2Fselfie.jpg",
  });
  assert.equal(path, "chat_photos/uidA_uidB/uidA/msg1.jpg");
  assert.ok(!path!.includes("identity_verifications"));
});

test("F-1: admin panel nüsxəsi paylaşılan post medyasına toxunmur", () => {
  assert.equal(
    adminPanelPath("uidA_uidB", "msg1", {
      type: "post",
      senderId: "uidA",
      mediaUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/posts%2FuidC%2Fclip.mp4",
    }),
    null,
  );
});

test("F-1 PARITY: iki implementasiya bütün hallarda EYNİ nəticə verir", () => {
  const chatIds = ["uidA_uidB", "a/../b", "x_y"];
  const messageIds = ["msg1", "m/../x"];
  const types = ["image", "video", "audio", "text", "post", "call", "sticker", undefined];
  const senders = ["uidA", "u/../v", "", 42, undefined];
  const urls = [
    undefined,
    "",
    "https://firebasestorage.googleapis.com/v0/b/x/o/chat_photos%2Fa%2Fb%2Fc.jpg?alt=media",
    "x/o/profile_photos%2Fvictim%2Fp.jpg",
    "https://evil.test/o/identity_verifications%2Fv%2Fr%2Fs.jpg",
    "/o/",
  ];

  let compared = 0;
  for (const chatId of chatIds) {
    for (const messageId of messageIds) {
      for (const type of types) {
        for (const senderId of senders) {
          for (const mediaUrl of urls) {
            const data: Record<string, unknown> = {};
            if (type !== undefined) data.type = type;
            if (senderId !== undefined) data.senderId = senderId;
            if (mediaUrl !== undefined) data.mediaUrl = mediaUrl;
            assert.equal(
              chatMediaPathForMessage(chatId, messageId, data),
              adminPanelPath(chatId, messageId, data),
              `drift: chatId=${chatId} messageId=${messageId} data=${JSON.stringify(data)}`,
            );
            compared++;
          }
        }
      }
    }
  }
  assert.ok(compared >= 700, `gözlənildiyindən az hal yoxlandı: ${compared}`);
});

// ── A3-H2 — `_200x200` törəmə yolu ────────────────────────────────
//
// Bu funksiya silinən şeyi genişləndirir, ona görə səhvi bir istiqamətdə
// təhlükəlidir: səhv yol qaytarsa, BAŞQA birinin faylı silinər.

test("törəmə yolu: adi hallar", () => {
  assert.equal(
    resizedVariantPath("chat_photos/a_b/a/m1.jpg"),
    "chat_photos/a_b/a/m1_200x200.jpg",
  );
  assert.equal(resizedVariantPath("venue_photos/v1.jpg"), "venue_photos/v1_200x200.jpg");
  assert.equal(resizedVariantPath("a/b/c/d.png"), "a/b/c/d_200x200.png");
});

test("törəmə yolu: null qaytarmalı hallar", () => {
  assert.equal(resizedVariantPath(""), null);
  assert.equal(resizedVariantPath(undefined), null);
  assert.equal(resizedVariantPath(null), null);
  assert.equal(resizedVariantPath(42), null);
  // Uzantı yoxdur.
  assert.equal(resizedVariantPath("posts/uid/file"), null);
  // Nöqtə qovluq adındadır, fayl adında yox — uzantı sayılmamalıdır.
  assert.equal(resizedVariantPath("a.b/c"), null);
  // Nöqtə ilə başlayan fayl adı (gizli fayl) — uzantı deyil.
  assert.equal(resizedVariantPath("posts/uid/.hidden"), null);
  // Artıq törəmədir — ikiqat şəkilçi yaranmamalıdır.
  assert.equal(resizedVariantPath("posts/uid/p_200x200.jpg"), null);
});

test("törəmə yolu: hər iki kod bazası eyni cavabı verir (paritet)", () => {
  const inputs: unknown[] = [
    "chat_photos/a_b/a/m1.jpg", "venue_photos/v1.jpg", "offer_photos/o1.jpeg",
    "a/b/c/d.png", "posts/uid/file", "a.b/c", "posts/uid/.hidden",
    "posts/uid/p_200x200.jpg", "", "x.jpg", "no-slash.png",
    undefined, null, 42, {}, [],
  ];
  for (const input of inputs) {
    assert.equal(
      resizedVariantPath(input),
      adminResizedVariantPath(input),
      `fərq: ${JSON.stringify(input)}`,
    );
  }
});
