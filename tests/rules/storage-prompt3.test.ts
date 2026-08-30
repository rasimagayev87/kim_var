// Düzəliş Prompt 12 — Prompt 3 (Storage sahiblik) davranış testləri.
// Əhatə: storage.rules — 4 owner-scoped yol, köhnə flat-yol keçid
// dövrü, chat media sender-only delete, ölçü/content-type limitləri.
import { after, before, describe, test } from "node:test";
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";

import { createTestEnv } from "./helpers.ts";

let testEnv: RulesTestEnvironment;

const smallJpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0, 1, 2, 3]);
const oversized = new Uint8Array(6 * 1024 * 1024); // > 5MB venue/offer/pinbox/event limiti

before(async () => {
  testEnv = await createTestEnv();
  // Warm-up (infrastruktur, rules DEYİL) — Storage emulator-un rules
  // mühərriki (ayrıca JVM prosesi, `cloud-storage-rules-runtime-*.jar`)
  // bu faylın BİRİNCİ real yazısında bəzən keçici `storage/unauthorized`
  // qaytarır (tam Firestore+Storage suite-i ilə birlikdə işlədikdə
  // təkrarlana bilən, YALNIZ Storage tərəfinin öz emulator-a
  // qoşulma/isinmə vaxtına aid bir gecikmə — eyni test tək başına
  // işlədikdə heç vaxt baş vermir). Əsl testlərdən əvvəl kiçik, əlaqəsiz
  // bir yazı ilə "isindirilir"; nəticəsi əhəmiyyətsizdir, yalnız rules
  // mühərrikinin hazır olmasını gözləyir.
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const warmupUid = "storage-warmup-uid";
      await uploadBytes(
        ref(testEnv.authenticatedContext(warmupUid).storage(), `profile_photos/${warmupUid}/warmup.jpg`),
        smallJpeg,
        { contentType: "image/jpeg" },
      );
      break;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 300));
    }
  }
});

after(async () => {
  await testEnv.cleanup();
});

interface OwnerScopedCase {
  label: string;
  prefix: string;
}

const ownerScopedPaths: OwnerScopedCase[] = [
  { label: "venue_photos", prefix: "venue_photos" },
  { label: "offer_photos", prefix: "offer_photos" },
  { label: "pinbox_photos", prefix: "pinbox_photos" },
  { label: "event_covers", prefix: "event_covers" },
];

describe("Prompt 3 — owner-scoped Storage yolları (venue/offer/pinbox/event)", () => {
  for (const { label, prefix } of ownerScopedPaths) {
    test(`${label}: öz uid-inə yükləmə keçir`, async () => {
      const uid = `p3-${label}-owner`;
      const storage = testEnv.authenticatedContext(uid).storage();
      await assertSucceeds(
        uploadBytes(ref(storage, `${prefix}/${uid}/item.jpg`), smallJpeg, { contentType: "image/jpeg" }),
      );
    });

    test(`${label}: başqasının uid-inə yükləmə rədd edilir`, async () => {
      const uid = `p3-${label}-attacker`;
      const victim = `p3-${label}-victim`;
      const storage = testEnv.authenticatedContext(uid).storage();
      await assertFails(
        uploadBytes(ref(storage, `${prefix}/${victim}/item.jpg`), smallJpeg, { contentType: "image/jpeg" }),
      );
    });
  }
});

describe("Prompt 3 — köhnə flat yol keçid dövrü", () => {
  const oldPath = "venue_photos/legacy-venue-id.jpg";

  before(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), oldPath), smallJpeg, { contentType: "image/jpeg" });
    });
  });

  test("köhnə flat yola YENİ yazı rədd edilir", async () => {
    const storage = testEnv.authenticatedContext("p3-legacy-writer").storage();
    await assertFails(uploadBytes(ref(storage, oldPath), smallJpeg, { contentType: "image/jpeg" }));
  });

  test("köhnə flat yoldan oxuma keçir (keçid dövrü)", async () => {
    const storage = testEnv.authenticatedContext("p3-legacy-reader").storage();
    await assertSucceeds(getBytes(ref(storage, oldPath)));
  });
});

describe("Prompt 3 — chat media sender-only delete (RT-8)", () => {
  const sender = "p3-chat-sender";
  const receiver = "p3-chat-receiver";
  const chatId = [sender, receiver].sort().join("_");
  const path = `chat_photos/${chatId}/${sender}/msg1.jpg`;

  test("göndərən öz yoluna yükləyir — keçir", async () => {
    const storage = testEnv.authenticatedContext(sender).storage();
    await assertSucceeds(uploadBytes(ref(storage, path), smallJpeg, { contentType: "image/jpeg" }));
  });

  test("alıcı göndərənin faylını silməyə cəhd edərsə rədd edilir", async () => {
    const storage = testEnv.authenticatedContext(receiver).storage();
    await assertFails(deleteObject(ref(storage, path)));
  });

  test("göndərən öz faylını silə bilir", async () => {
    const storage = testEnv.authenticatedContext(sender).storage();
    await assertSucceeds(deleteObject(ref(storage, path)));
  });
});

describe("Prompt 3 — ölçü və content-type limitləri", () => {
  test("5MB-dan böyük fayl rədd edilir (venue_photos)", async () => {
    const uid = "p3-oversize-owner";
    const storage = testEnv.authenticatedContext(uid).storage();
    await assertFails(
      uploadBytes(ref(storage, `venue_photos/${uid}/big.jpg`), oversized, { contentType: "image/jpeg" }),
    );
  });

  test("yanlış content-type rədd edilir (venue_photos, image/* gözlənilir)", async () => {
    const uid = "p3-wrongtype-owner";
    const storage = testEnv.authenticatedContext(uid).storage();
    await assertFails(
      uploadBytes(ref(storage, `venue_photos/${uid}/doc.jpg`), smallJpeg, { contentType: "application/pdf" }),
    );
  });
});

// Say: 15 test (owner-scoped 4 yol × 2 = 8, köhnə yol 2, chat media 3,
// ölçü/content-type 2).

// ---------------------------------------------------------------------------
// P0 / M-10 — content-type allowlist. `image/.*` `image/svg+xml`-i də
// qəbul edirdi; Storage obyekti saxlanılan Content-Type ilə `inline`
// təqdim etdiyi üçün bu, firebasestorage.googleapis.com mənşəyində
// JavaScript icra edən sənəd — saxlanılmış XSS deməkdir.
// ---------------------------------------------------------------------------
describe("P0 / M-10 — content-type allowlist (SVG rədd edilir)", () => {
  const uid = "m10-user";

  test("SVG RƏDD EDİLİR (əsas vektor) — profil, məkan, story, post", async () => {
    const storage = testEnv.authenticatedContext(uid).storage();
    const svg = new Uint8Array([0x3c, 0x73, 0x76, 0x67, 0x3e]); // "<svg>"
    for (const path of [
      `profile_photos/${uid}/profile.jpg`,
      `venue_photos/${uid}/v1.jpg`,
      `offer_photos/${uid}/o1.jpg`,
      `pinbox_photos/${uid}/p1.jpg`,
      `event_covers/${uid}/e1.jpg`,
      `stories/${uid}/s1.jpg`,
      `posts/${uid}/p1.jpg`,
      `identity_verifications/${uid}/req1/front.jpg`,
    ]) {
      await assertFails(
        uploadBytes(ref(storage, path), svg, { contentType: "image/svg+xml" }),
      );
    }
  });

  test("SVG çat medyasında da rədd edilir", async () => {
    const other = "m10-other";
    const chatId = [uid, other].sort().join("_");
    const storage = testEnv.authenticatedContext(uid).storage();
    await assertFails(
      uploadBytes(ref(storage, `chat_photos/${chatId}/${uid}/m1.jpg`), new Uint8Array([1]), {
        contentType: "image/svg+xml",
      }),
    );
  });

  test("real şəkil formatları qəbul edilir (reqressiya yoxdur)", async () => {
    const storage = testEnv.authenticatedContext(uid).storage();
    for (const contentType of ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif", "image/gif"]) {
      await assertSucceeds(
        uploadBytes(ref(storage, `profile_photos/${uid}/profile.jpg`), new Uint8Array([1, 2, 3]), { contentType }),
      );
    }
  });

  test("video/audio allowlist-ləri işləyir", async () => {
    const other = "m10-other2";
    const chatId = [uid, other].sort().join("_");
    const storage = testEnv.authenticatedContext(uid).storage();
    await assertSucceeds(
      uploadBytes(ref(storage, `chat_videos/${chatId}/${uid}/v1.mp4`), new Uint8Array([1]), {
        contentType: "video/mp4",
      }),
    );
    await assertSucceeds(
      uploadBytes(ref(storage, `chat_audio/${chatId}/${uid}/a1.m4a`), new Uint8Array([1]), {
        contentType: "audio/m4a",
      }),
    );
    // HTML video qovluğunda da rədd edilməlidir.
    await assertFails(
      uploadBytes(ref(storage, `chat_videos/${chatId}/${uid}/v2.mp4`), new Uint8Array([1]), {
        contentType: "text/html",
      }),
    );
  });
});
