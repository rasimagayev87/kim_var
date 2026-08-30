// Self-verification / a2 + d6 — H-1 and H-2 were the only two P0 fixes
// with no regression test. These are the assertions that were missing.
//
// Pure functions only: no emulator, no Admin SDK. See `functions/src/
// geo.ts` for why this logic was extracted in the first place.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  bucketDistanceMeters,
  clampAudienceRadiusKm,
  haversineMeters,
  isPlausibleMovement,
  reportableAudienceCount,
  NEARBY_MAX_PLAUSIBLE_SPEED_KMH,
  NEARBY_PROBE_WINDOW_MS,
  VENUE_AUDIENCE_MAX_RADIUS_KM,
  VENUE_AUDIENCE_MIN_REPORTABLE_COUNT,
} from "../../functions/src/geo";

describe("H-1 (a) — məsafə kvantlaşdırması", () => {
  test("100 m-dən yaxın hər şey 100 m kimi bildirilir", () => {
    // Bu, funksiyanın BÜTÜN məqsədidir: 0 m "yanınızda dayanıb"
    // deməkdir və bu cavab heç vaxt verilməməlidir.
    for (const m of [0, 1, 12, 49, 50, 99]) {
      assert.equal(bucketDistanceMeters(m), 100, `${m} m`);
    }
  });

  test("100-ün qatlarına yuvarlaqlaşır", () => {
    assert.equal(bucketDistanceMeters(149), 100);
    assert.equal(bucketDistanceMeters(150), 200);
    assert.equal(bucketDistanceMeters(151), 200);
    assert.equal(bucketDistanceMeters(1249), 1200);
    assert.equal(bucketDistanceMeters(1250), 1300);
  });

  test("nəticə heç vaxt daha yaxın göstərmir", () => {
    // Kvantlaşdırma yuxarı da yuvarlaqlaya bilər (uzaqlaşdırır — zərərsiz),
    // amma 100 m-lik döşəmə heç vaxt pozulmur.
    for (let m = 0; m <= 3000; m += 7) {
      assert.ok(bucketDistanceMeters(m) >= 100, `${m} m üçün döşəmə pozuldu`);
    }
  });
});

describe("H-2 — k-anonimlik döşəməsi", () => {
  test("hədddən aşağı saylar 0 qaytarır", () => {
    for (let c = 0; c < VENUE_AUDIENCE_MIN_REPORTABLE_COUNT; c++) {
      assert.equal(reportableAudienceCount(c), 0, `count=${c}`);
    }
  });

  test("hədd və yuxarısı olduğu kimi qaytarılır", () => {
    assert.equal(reportableAudienceCount(5), 5);
    assert.equal(reportableAudienceCount(6), 6);
    assert.equal(reportableAudienceCount(2000), 2000);
  });

  test("hədd 5-dir — dəyişsə bu test xəbər verir", () => {
    // Rəqəmin özü qərardır (bax `docs/security-audit-2-*.md`, H-2).
    // Səssizcə aşağı salınması məhz qorunan şeyi açar.
    assert.equal(VENUE_AUDIENCE_MIN_REPORTABLE_COUNT, 5);
  });
});

describe("H-2 — radius clamp", () => {
  test("50 km-dən yuxarı istəklər kəsilir", () => {
    assert.equal(clampAudienceRadiusKm(51), 50);
    assert.equal(clampAudienceRadiusKm(20000), 50);
    assert.equal(clampAudienceRadiusKm(Number.MAX_SAFE_INTEGER), 50);
  });

  test("hədd daxilindəki istəklər toxunulmur", () => {
    assert.equal(clampAudienceRadiusKm(1), 1);
    assert.equal(clampAudienceRadiusKm(50), 50);
    assert.equal(VENUE_AUDIENCE_MAX_RADIUS_KM, 50);
  });
});

describe("H-1 (b) — hərəkətin ağlabatanlığı", () => {
  const now = 1_700_000_000_000;
  const baku = { lat: 40.4093, lng: 49.8671 };
  const london = { lat: 51.5074, lng: -0.1278 };

  test("əvvəlki probe yoxdursa icazə verilir", () => {
    assert.equal(isPlausibleMovement(undefined, baku.lat, baku.lng, now), true);
    assert.equal(isPlausibleMovement({}, baku.lat, baku.lng, now), true);
  });

  test("natamam/yararsız probe icazə verilir (uydurmaqdansa buraxmaq)", () => {
    assert.equal(isPlausibleMovement({ lat: 40, lng: null, at: now - 1000 }, baku.lat, baku.lng, now), true);
    assert.equal(isPlausibleMovement({ lat: "40", lng: 49, at: now - 1000 }, baku.lat, baku.lng, now), true);
  });

  test("pəncərədən köhnə probe müqayisə edilmir", () => {
    // 15 dəqiqədən sonra insan həqiqətən istənilən yerdə ola bilər.
    const old = { lat: london.lat, lng: london.lng, at: now - NEARBY_PROBE_WINDOW_MS - 1 };
    assert.equal(isPlausibleMovement(old, baku.lat, baku.lng, now), true);
  });

  test("Londondan Bakıya 1 dəqiqədə — rədd edilir", () => {
    const prev = { lat: london.lat, lng: london.lng, at: now - 60_000 };
    assert.equal(isPlausibleMovement(prev, baku.lat, baku.lng, now), false);
  });

  test("real şəhərdaxili hərəkət qəbul edilir", () => {
    // ~2 km, 5 dəqiqə = 24 km/saat.
    const prev = { lat: 40.4093, lng: 49.8671, at: now - 300_000 };
    assert.equal(isPlausibleMovement(prev, 40.4273, 49.8671, now), true);
  });

  test("hədd 300 km/saatın hər iki tərəfi", () => {
    const hourMs = 3_600_000;
    // 299 km/saat: 1 saatda 299 km — amma pəncərə 15 dəqiqədir, ona görə
    // 10 dəqiqədə mütənasib məsafə götürülür.
    const tenMin = hourMs / 6;
    const kmIn10Min = (kmh: number) => (kmh * 10) / 60;
    const degPerKm = 1 / 111.32; // ekvatorda enlik dərəcəsi
    const under = { lat: 0, lng: 0, at: now - tenMin };
    const overLat = kmIn10Min(NEARBY_MAX_PLAUSIBLE_SPEED_KMH + 40) * degPerKm;
    const underLat = kmIn10Min(NEARBY_MAX_PLAUSIBLE_SPEED_KMH - 40) * degPerKm;
    assert.equal(isPlausibleMovement(under, underLat, 0, now), true, "hədd altı buraxılmalıdır");
    assert.equal(isPlausibleMovement(under, overLat, 0, now), false, "hədd üstü rədd edilməlidir");
  });

  test("gələcəyə aid probe (saat sürüşməsi) icazə verilir, sıfıra bölmə yoxdur", () => {
    const future = { lat: london.lat, lng: london.lng, at: now + 5000 };
    assert.equal(isPlausibleMovement(future, baku.lat, baku.lng, now), true);
    const same = { lat: london.lat, lng: london.lng, at: now };
    assert.equal(isPlausibleMovement(same, baku.lat, baku.lng, now), true);
  });
});

describe("haversineMeters", () => {
  test("eyni nöqtə 0 verir", () => {
    assert.equal(haversineMeters(40.4093, 49.8671, 40.4093, 49.8671), 0);
  });

  test("Bakı–London məsafəsi təxminən düzgündür", () => {
    const m = haversineMeters(40.4093, 49.8671, 51.5074, -0.1278);
    assert.ok(m > 3_900_000 && m < 4_100_000, `alındı: ${Math.round(m)} m`);
  });
});
