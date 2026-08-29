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
