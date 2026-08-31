/**
 * The daily opportunity digest (`functions/src/digest.ts`).
 *
 * These assert the four rules that make the digest a digest rather
 * than the fan-out it replaced: the recipient's own radius decides
 * reach, a venue owner never hears about their own listing, an empty
 * type sends nothing at all, and one user gets at most three
 * notifications no matter how many venues published.
 *
 * The last one is the whole point of the change — "5 new campaigns"
 * and "47 new campaigns" must cost the same single push, or the
 * notification count grows with the venue count and the app gets
 * uninstalled.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  DIGEST_LOOKBACK_MS,
  DigestIntent,
  DigestRecipient,
  digestCountsFor,
  digestNotifications,
  INTENT_RETENTION_DAYS,
  INTENT_TYPES,
  isIntentInReach,
  MAX_DIGEST_NOTIFICATIONS_PER_USER,
} from "../../functions/src/digest";

const BAKU = { lat: 40.4093, lng: 49.8671 };

function intent(over: Partial<DigestIntent> = {}): DigestIntent {
  return { type: "offer", venueId: "v1", ownerId: "owner", ...BAKU, ...over };
}

function recipient(over: Partial<DigestRecipient> = {}): DigestRecipient {
  return { uid: "u1", ...BAKU, discoverRadiusMode: "distance", discoverRadiusKm: 5, ...over };
}

describe("isIntentInReach — alıcının öz radiusu yeganə coğrafi qapıdır", () => {
  test("radius daxilində — keçir", () => {
    assert.equal(isIntentInReach(intent(), recipient()), true);
  });

  test("radiusdan kənar — keçmir", () => {
    // ~11 km şimala
    const far = intent({ lat: BAKU.lat + 0.1 });
    assert.equal(isIntentInReach(far, recipient({ discoverRadiusKm: 5 })), false);
  });

  test("məkan geniş yayımlasa da alıcının dar radiusu üstündür", () => {
    const far = intent({ lat: BAKU.lat + 0.1 });
    assert.equal(isIntentInReach(far, recipient({ discoverRadiusKm: 1 })), false);
  });

  test("'world' rejimi hər şeyi qəbul edir", () => {
    const far = intent({ lat: 51.5074, lng: -0.1278 });
    assert.equal(isIntentInReach(far, recipient({ discoverRadiusMode: "world" })), true);
  });

  test("'country' rejimi ölkəni tutuşdurur", () => {
    const r = recipient({ discoverRadiusMode: "country", country: "AZ" });
    assert.equal(isIntentInReach(intent(), r, "AZ"), true);
    assert.equal(isIntentInReach(intent(), r, "TR"), false);
    assert.equal(isIntentInReach(intent(), r, undefined), false);
  });

  test("rejim yoxdursa məhdudiyyətsiz sayılır — Discover-i heç açmayan itmir", () => {
    const far = intent({ lat: 51.5074, lng: -0.1278 });
    assert.equal(isIntentInReach(far, recipient({ discoverRadiusMode: undefined })), true);
  });

  test("mövqeyi olmayan alıcı məsafə rejimində çıxarılır", () => {
    assert.equal(isIntentInReach(intent(), recipient({ lat: undefined, lng: undefined })), false);
  });
});

describe("digestCountsFor", () => {
  test("növ üzrə sayır", () => {
    const counts = digestCountsFor(
      [intent({ type: "offer" }), intent({ type: "offer" }), intent({ type: "pinbox" })],
      recipient(),
    );
    assert.deepEqual(counts, { offer: 2, pinbox: 1 });
  });

  test("SAHİB öz məzmununu almır", () => {
    const counts = digestCountsFor(
      [intent({ ownerId: "u1" }), intent({ ownerId: "someone-else" })],
      recipient({ uid: "u1" }),
    );
    assert.deepEqual(counts, { offer: 1 }, "yalnız özgənin elanı sayılmalıdır");
  });

  test("sahibin BÜTÜN elanları öz digest-indən çıxır", () => {
    const counts = digestCountsFor(
      [intent({ ownerId: "u1", type: "offer" }), intent({ ownerId: "u1", type: "pinbox" })],
      recipient({ uid: "u1" }),
    );
    assert.deepEqual(counts, {}, "sahib öz üç elanı barədə bildiriş almamalıdır");
  });

  test("radiusdan kənar elanlar sayılmır", () => {
    const counts = digestCountsFor(
      [intent(), intent({ lat: BAKU.lat + 0.5 })],
      recipient({ discoverRadiusKm: 5 }),
    );
    assert.deepEqual(counts, { offer: 1 });
  });

  test("boş giriş boş nəticə verir", () => {
    assert.deepEqual(digestCountsFor([], recipient()), {});
  });
});

describe("digestNotifications — hədd və sıfır davranışı", () => {
  test("SIFIR olan növ ÜMUMİYYƏTLƏ göndərilmir", () => {
    // "0 yeni PinBox" bildirişi göndərmək tələbin birbaşa pozulmasıdır.
    const out = digestNotifications({ offer: 3 });
    assert.deepEqual(out, [{ type: "offer", count: 3 }]);
  });

  test("heç nə yoxdursa heç bir bildiriş yoxdur", () => {
    assert.deepEqual(digestNotifications({}), []);
  });

  test("MAKSİMUM 3 — məkan sayından asılı deyil", () => {
    // Əsas iddia: 5 kampaniya da, 47 kampaniya da BİR bildirişdir.
    const many = Array.from({ length: 47 }, () => intent({ type: "offer" }))
      .concat(Array.from({ length: 12 }, () => intent({ type: "pinbox" })))
      .concat(Array.from({ length: 30 }, () => intent({ type: "event" })));
    const out = digestNotifications(digestCountsFor(many, recipient()));
    assert.equal(out.length, 3, "89 elan üçün 3 bildiriş");
    assert.ok(out.length <= MAX_DIGEST_NOTIFICATIONS_PER_USER);
    assert.deepEqual(out.map((o) => o.count), [47, 12, 30], "saylar mətn üçün saxlanılır");
  });

  test("sıra həmişə eynidir — Map iterasiyasından asılı deyil", () => {
    const out = digestNotifications({ event: 1, offer: 1, pinbox: 1 });
    assert.deepEqual(out.map((o) => o.type), [...INTENT_TYPES]);
  });
});

describe("saxlama müddəti — korrektlik, diaqnostika deyil", () => {
  test("geriyə baxış 24 saatdır", () => {
    assert.equal(DIGEST_LOOKBACK_MS, 24 * 60 * 60 * 1000);
  });

  test("saxlama ən azı 2 gündür — 24 saatlıq pəncərə iki təqvim gününə düşür", () => {
    // 15:00-da işləyən dövr dünən axşamı və bugün səhəri əhatə edir.
    // 2-dən aşağı hər dəyər sakitcə elan itirər.
    assert.ok(INTENT_RETENTION_DAYS >= 2, "iki gün korrektlik minimumudur");
  });

  test("saxlama 3 gündür — buraxılmış işləmə üçün bir gün ehtiyat", () => {
    assert.equal(INTENT_RETENTION_DAYS, 3);
  });
});
