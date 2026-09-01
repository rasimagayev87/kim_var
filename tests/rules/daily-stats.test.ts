/**
 * The nightly venue rollup (`functions/src/daily-stats.ts`).
 *
 * Two things here would fail silently rather than loudly, so they are
 * what these tests pin: the k-anonymity floor returning `null` instead
 * of `0`, and the document schema quietly growing a field that
 * identifies somebody. Neither breaks a build; both break a promise
 * the privacy policy makes.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  DAILY_STATS_FIELDS,
  DAILY_STATS_RETENTION_DAYS,
  FORBIDDEN_STATS_FIELD_PATTERNS,
  VENUE_AUDIENCE_MIN_REPORTABLE_COUNT,
  aggregateAudienceSamples,
  dailyStatsDateKey,
  previousDateKey,
  reportableOrNull,
} from "../../functions/src/daily-stats";

describe("k-anonimlik həddi — `null`, `0` yox", () => {
  test("həddən aşağı dəyər null qaytarır", () => {
    for (let n = 0; n < VENUE_AUDIENCE_MIN_REPORTABLE_COUNT; n++) {
      assert.equal(reportableOrNull(n), null, `${n} açıq qaldı`);
    }
  });

  test("tam hədd özü hesabat verilə biləndir", () => {
    assert.equal(reportableOrNull(VENUE_AUDIENCE_MIN_REPORTABLE_COUNT), VENUE_AUDIENCE_MIN_REPORTABLE_COUNT);
  });

  test("«az» ilə «heç» eyni deyil — hər ikisi null, amma 0 heç vaxt yazılmır", () => {
    // Bu, testin mahiyyətidir. Əgər hədd 0 qaytarsaydı, aylıq hesabatda
    // «heç kim yox idi» ilə «5-dən az idi» eyni görünərdi — və bir ay
    // sıfırların içində tək bir 7 gizlədilən dəyəri açardı.
    assert.equal(reportableOrNull(0), null);
    assert.equal(reportableOrNull(4), null);
    assert.notEqual(reportableOrNull(4), 0);
  });

  test("say olmayan dəyərlər çökmür", () => {
    for (const v of [null, undefined, NaN, Infinity]) {
      assert.equal(reportableOrNull(v as number), null, `${v}`);
    }
  });

  test("hədd `geo.ts`-dən gəlir — yeni hədd icad edilməyib", () => {
    assert.equal(VENUE_AUDIENCE_MIN_REPORTABLE_COUNT, 5);
  });
});

describe("günün aqreqasiyası", () => {
  const s = (count: number, hour: number) => ({ count, hour });

  test("orta, pik və pik saat", () => {
    const r = aggregateAudienceSamples([s(10, 12), s(30, 20), s(20, 14)]);
    assert.deepEqual(r, { audienceAvg: 20, audiencePeak: 30, audiencePeakHour: 20, audienceSamples: 3 });
  });

  test("nümunə yoxdursa hamısı null, sayı 0", () => {
    assert.deepEqual(aggregateAudienceSamples([]), {
      audienceAvg: null, audiencePeak: null, audiencePeakHour: null, audienceSamples: 0,
    });
  });

  test("kiçik gün — orta və pik gizlədilir, nümunə sayı qalır", () => {
    // `audienceSamples` gizlədilmir: o, insanları yox, ölçmənin özünü
    // təsvir edir — «sakit gün» ilə «cədvəl işləməyib» fərqlənməlidir.
    const r = aggregateAudienceSamples([s(2, 10), s(3, 11), s(1, 12)]);
    assert.equal(r.audienceAvg, null);
    assert.equal(r.audiencePeak, null);
    assert.equal(r.audienceSamples, 3);
  });

  test("pik gizlədilirsə pik SAAT da gizlədilir", () => {
    // Sayı gizlədib «ən sıx saat 21:00 idi» demək, həmin saatda
    // konkret bir adamın orada olduğunu yenə açır.
    const r = aggregateAudienceSamples([s(3, 21), s(2, 22)]);
    assert.equal(r.audiencePeakHour, null);
  });

  test("orta xam nümunələrdən hesablanır, gizlədilmişlərdən yox", () => {
    // Hər nümunəni ayrıca gizlətsək, kiçik dəyərlər nəyəsə çevrilməli
    // olardı və orta yuxarı sürüşərdi. Xam orta hesablanır, sonra
    // bütövlükdə gizlədilir.
    const r = aggregateAudienceSamples([s(1, 8), s(1, 9), s(28, 20)]);
    assert.equal(r.audienceAvg, 10);
    assert.equal(r.audiencePeak, 28);
  });

  test("bərabər pik — ən erkən saat saxlanılır, təkrar icrada eynidir", () => {
    const input = [s(9, 13), s(9, 19)];
    assert.equal(aggregateAudienceSamples(input).audiencePeakHour, 13);
    assert.equal(aggregateAudienceSamples(input).audiencePeakHour, 13);
  });

  test("yararsız nümunələr atılır", () => {
    const r = aggregateAudienceSamples([s(10, 12), s(NaN, 5), s(20, 99), s(30, 14)]);
    assert.equal(r.audienceSamples, 2);
    assert.equal(r.audiencePeak, 30);
  });
});

describe("tarix açarları", () => {
  test("UTC `YYYY-MM-DD`", () => {
    assert.equal(dailyStatsDateKey(new Date("2026-09-01T23:59:59Z")), "2026-09-01");
  });

  test("gecə yarısından sonrakı icra DÜNƏNİ yığır", () => {
    // Funksiya 00:30 UTC-də işləyir; sənəd bitmiş günə aid olmalıdır.
    assert.equal(previousDateKey(new Date("2026-09-02T00:30:00Z")), "2026-09-01");
  });

  test("ay və il sərhədi", () => {
    assert.equal(previousDateKey(new Date("2026-09-01T00:30:00Z")), "2026-08-31");
    assert.equal(previousDateKey(new Date("2027-01-01T00:30:00Z")), "2026-12-31");
  });
});

describe("sxem — məxfilik zəmanəti", () => {
  test("heç bir sahə adı şəxsiyyət göstərmir", () => {
    // Bu siyahı məxfilik siyasətinin «yalnız aqreqat rəqəmlər»
    // vədidir. TypeScript altı ay sonra əlavə ediləcək `uid` sahəsini
    // dayandırmaz — bu test dayandırır.
    for (const field of DAILY_STATS_FIELDS) {
      for (const bad of FORBIDDEN_STATS_FIELD_PATTERNS) {
        assert.ok(
          !field.toLowerCase().includes(bad.toLowerCase()),
          `"${field}" sahəsi qadağan naxış "${bad}" ehtiva edir`,
        );
      }
    }
  });

  test("sxem dublikat sahə saxlamır", () => {
    assert.equal(new Set(DAILY_STATS_FIELDS).size, DAILY_STATS_FIELDS.length);
  });

  test("hər sənəddə tarix və TTL sahəsi var", () => {
    assert.ok(DAILY_STATS_FIELDS.includes("date"));
    assert.ok(DAILY_STATS_FIELDS.includes("expiresAt"));
  });
});

describe("saxlama müddəti", () => {
  test("400 gün — keçən ilin eyni ayı ilə müqayisə üçün", () => {
    assert.equal(DAILY_STATS_RETENTION_DAYS, 400);
    assert.ok(DAILY_STATS_RETENTION_DAYS > 365, "bir ildən az olsa mövsümilik müqayisəsi mümkün deyil");
  });
});

describe("index.ts ilə paritet", () => {
  test("rollUpVenueDailyStats gecə yarısından sonra işləyir", async () => {
    const { readFileSync } = await import("node:fs");
    const src = readFileSync(new URL("../../functions/src/index.ts", import.meta.url), "utf8");
    const m = /rollUpVenueDailyStats = onSchedule\(\s*\{ schedule: "([^"]+)"/.exec(src);
    assert.ok(m, "cədvəl tapılmadı");
    // Gün bitdikdən SONRA — əks halda sənəd natamam günü yığar.
    assert.match(m[1], /^30 0 \* \* \*$/);
  });

  test("yalnız təsdiqlənmiş məkanlar üçün işləyir", async () => {
    const { readFileSync } = await import("node:fs");
    const src = readFileSync(new URL("../../functions/src/index.ts", import.meta.url), "utf8");
    const i = src.indexOf("export const rollUpVenueDailyStats");
    const body = src.slice(i, i + 2500);
    assert.match(body, /where\("status", "==", "approved"\)/);
  });
});
