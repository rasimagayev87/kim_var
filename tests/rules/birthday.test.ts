/**
 * The birthday day-of-year comparison (`functions/src/birthday.ts`).
 *
 * Confirmed against a real production document before this was
 * written: `July 7, 1987 00:00 UTC+5` is stored as
 * `1987-07-06T19:00:00Z`, and the old `getUTCDate()` answered 6. Every
 * birthday notification went out a day early.
 *
 * The case that rules out the obvious repair is the same one:
 * Azerbaijan was UTC+5 in July 1987 and is UTC+4 today, so "subtract
 * the offset" needs a different offset per birth year. Only a real
 * timezone lookup gets both right, which is what these tests pin.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import { APP_TIME_ZONE, bakuDateKey, bakuHour, bakuMonthDay, isBirthdayToday } from "../../functions/src/birthday";

describe("bakuMonthDay — tarixi qurşaq qaydaları", () => {
  test("1987 yay vaxtı (UTC+5) — əsl hal, Console-dan təsdiqlənib", () => {
    // `July 7, 1987 00:00 UTC+5` → saxlanan UTC dəyəri
    const stored = new Date("1987-07-06T19:00:00Z");
    assert.equal(bakuMonthDay(stored), "07-07", "ad günü 7 iyul olmalıdır, 6 yox");
  });

  test("KÖHNƏ DAVRANIŞ səhv idi — getUTCDate() bir gün geri qaytarır", () => {
    // Düzəlişin nəyi dəyişdiyini sənədləşdirir: bu sətir keçərsə,
    // sürüşmə real idi.
    const stored = new Date("1987-07-06T19:00:00Z");
    assert.equal(stored.getUTCDate(), 6);
    assert.equal(bakuMonthDay(stored), "07-07");
  });

  test("müasir tarix (UTC+4, yay vaxtı yoxdur)", () => {
    // 2001-05-01 00:00 +04 → 2001-04-30T20:00Z
    assert.equal(bakuMonthDay(new Date("2001-04-30T20:00:00Z")), "05-01");
  });

  test("1 yanvar — il sərhədi", () => {
    // 2000-01-01 00:00 +04 → 1999-12-31T20:00Z
    assert.equal(bakuMonthDay(new Date("1999-12-31T20:00:00Z")), "01-01");
    assert.equal(bakuDateKey(new Date("1999-12-31T20:00:00Z")), "2000-01-01");
  });

  test("31 dekabr — ilin son günü", () => {
    assert.equal(bakuMonthDay(new Date("1999-12-30T20:00:00Z")), "12-31");
  });

  test("29 fevral — uzun il", () => {
    // 2000-02-29 00:00 +04 → 2000-02-28T20:00Z
    assert.equal(bakuMonthDay(new Date("2000-02-28T20:00:00Z")), "02-29");
  });

  test("UTC gecə yarısı da düzgün oxunur (offset-siz saxlanmış dəyər)", () => {
    // Bəzi köhnə sənədlər UTC gecə yarısı ola bilər — həmin halda
    // Bakı vaxtı elə həmin gündür (04:00), sürüşmə yoxdur.
    assert.equal(bakuMonthDay(new Date("1995-03-15T00:00:00Z")), "03-15");
  });

  test("zona sabiti Asia/Baku-dur", () => {
    assert.equal(APP_TIME_ZONE, "Asia/Baku");
  });
});

describe("isBirthdayToday", () => {
  test("1987 doğumlu üçün düzgün gündə true", () => {
    const born = new Date("1987-07-06T19:00:00Z"); // 7 iyul, Bakı
    const today = new Date("2026-07-06T20:30:00Z"); // 7 iyul 00:30, Bakı
    assert.equal(isBirthdayToday(born, today), true);
  });

  test("bir gün əvvəl FALSE — düzəlişin bütün mahiyyəti", () => {
    const born = new Date("1987-07-06T19:00:00Z"); // 7 iyul
    const today = new Date("2026-07-05T20:30:00Z"); // 6 iyul, Bakı
    assert.equal(isBirthdayToday(born, today), false);
  });

  test("il fərqi əhəmiyyət daşımır, yalnız ay-gün", () => {
    assert.equal(
      isBirthdayToday(new Date("1987-07-06T19:00:00Z"), new Date("2030-07-06T21:00:00Z")),
      true,
    );
  });

  // ── 29 fevral: uzun olmayan ildə 28 fevralda qeyd olunur ────────
  // Məhsul qərarı (2026-08-31): ad günü tamamilə itməməlidir, və
  // 1 mart onu növbəti aya keçirir.
  const bornFeb29 = new Date("2000-02-28T20:00:00Z"); // Bakıda 29 fevral

  test("doğum tarixi həqiqətən 29 fevral kimi oxunur", () => {
    assert.equal(bakuMonthDay(bornFeb29), "02-29");
  });

  test("UZUN ildə 29 fevralda uyğun gəlir", () => {
    // 2024-02-29 00:30 Bakı → 2024-02-28T20:30Z
    assert.equal(isBirthdayToday(bornFeb29, new Date("2024-02-28T20:30:00Z")), true);
  });

  test("uzun ildə 28 fevralda uyğun GƏLMİR", () => {
    assert.equal(isBirthdayToday(bornFeb29, new Date("2024-02-27T20:30:00Z")), false);
  });

  test("UZUN OLMAYAN ildə 28 fevralda uyğun gəlir", () => {
    // 2025-02-28 00:30 Bakı → 2025-02-27T20:30Z
    assert.equal(isBirthdayToday(bornFeb29, new Date("2025-02-27T20:30:00Z")), true);
  });

  test("uzun olmayan ildə 1 martda uyğun GƏLMİR — aya sadiq qalır", () => {
    assert.equal(isBirthdayToday(bornFeb29, new Date("2025-02-28T20:30:00Z")), false);
  });

  test("28 fevralda doğulan şəxs təsirlənmir", () => {
    const bornFeb28 = new Date("1999-02-27T20:00:00Z"); // Bakıda 28 fevral
    assert.equal(isBirthdayToday(bornFeb28, new Date("2025-02-27T20:30:00Z")), true, "uzun olmayan il");
    assert.equal(isBirthdayToday(bornFeb28, new Date("2024-02-27T20:30:00Z")), true, "uzun il");
    assert.equal(isBirthdayToday(bornFeb28, new Date("2024-02-28T20:30:00Z")), false, "29 fevral onun günü deyil");
  });

  test("əsr qaydası: 2000 uzun ildir (%400), 2100 deyil (%100)", () => {
    // 1900 ilə yoxlamaq cazibədardır, amma o tarixdə Bakı `+04` deyil,
    // LMT (+03:19) idi — və doğum tarixi seçicisi onsuz da yalnız 100
    // il geriyə gedir. `%400` budağı üçün 2000/2100 cütü eyni qaydanı
    // yoxlayır, hər ikisi `+04` zonasındadır.
    assert.equal(isBirthdayToday(bornFeb29, new Date("2000-02-28T20:30:00Z")), true, "2000 → 29 fevral");
    assert.equal(isBirthdayToday(bornFeb29, new Date("2100-02-27T20:30:00Z")), true, "2100 → 28 fevral");
    assert.equal(isBirthdayToday(bornFeb29, new Date("2100-02-28T20:30:00Z")), false, "2100-də 29 fevral yoxdur");
  });
});

describe("bakuHour — 13:00 kəsimi Bakı vaxtı ilə oxunur", () => {
  // `publishLateBirthdayOfferIfNeeded` bu funksiya ilə "13:00 keçibmi"
  // sualını verir. Cloud Functions icra saatı UTC-dir, `onSchedule`-ın
  // `timeZone`-u yalnız işə salma vaxtını idarə edir — `getHours()`
  // istifadə etsəydik kəsim yerli 09:00-a düşərdi və günün bütün
  // kampaniyaları bir-bir yayımlanardı.
  test("UTC 09:00 → Bakıda 13:00", () => {
    assert.equal(bakuHour(new Date("2026-08-31T09:00:00Z")), 13);
  });

  test("UTC 08:59 → Bakıda 12:59, yəni hələ kəsimdən əvvəl", () => {
    assert.equal(bakuHour(new Date("2026-08-31T08:59:00Z")), 12);
  });

  test("gecə yarısı 24 yox, 0 qaytarır", () => {
    // `hour12: false` bəzi ICU versiyalarında 24 verir; `hourCycle:
    // "h23"` olmasa bu test sınardı.
    assert.equal(bakuHour(new Date("2026-08-30T20:00:00Z")), 0);
  });

  test("gün ərzində monoton artır", () => {
    const hours = [0, 4, 9, 15, 19].map((h) => bakuHour(new Date(Date.UTC(2026, 7, 31, h))));
    assert.deepEqual(hours, [4, 8, 13, 19, 23]);
  });
});
