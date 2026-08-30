// BACKLOG #8 — E.164 normalizasiyası (saf funksiya, emulator lazım deyil).
//
// Canlıda tapılan pozuq dəyər: `+994+994502749898` — istifadəçi tam
// beynəlxalq nömrəni YAZIB, sonra ölkə seçib; `_applyDialCodeForCountry`
// isə mövcud mətni "yerli hissə" sayıb prefiksi ikinci dəfə əlavə edib.
// Client düzəldildi, amma nömrə yalnız bir dəfə (onboarding-də) yazılır
// və redaktə ekranı yoxdur — yəni köhnə build-dən gələn dəyər əbədidir.
// Ona görə server də normalizə edir; bu testlər həmin server məntiqidir.
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  InvalidPhoneNumberError,
  isNormalizedPhoneNumber,
  normalizePhoneNumber,
} from "../../functions/src/phone";

describe("normalizePhoneNumber — canlı hadisə", () => {
  test("ikiqat ölkə prefiksi düzəldilir (production-dakı dəyər)", () => {
    assert.equal(normalizePhoneNumber("+994+994502749898"), "+994502749898");
  });

  test("ikiqat prefiks aralarında boşluqla da düzəldilir", () => {
    assert.equal(normalizePhoneNumber("+994 +994 50 274 98 98"), "+994502749898");
  });
});

describe("normalizePhoneNumber — düzgün nömrələr POZULMUR", () => {
  for (const ok of ["+994502749898", "+441234567890", "+12025550123", "+905321234567"]) {
    test(`dəyişmir: ${ok}`, () => {
      assert.equal(normalizePhoneNumber(ok), ok);
      assert.equal(isNormalizedPhoneNumber(ok), true);
    });
  }

  test("insan yazısındakı ayırıcılar təmizlənir", () => {
    assert.equal(normalizePhoneNumber("+994 50 274 98 98"), "+994502749898");
    assert.equal(normalizePhoneNumber("+994-50-274-98-98"), "+994502749898");
    assert.equal(normalizePhoneNumber(" +994 (50) 274.98.98 "), "+994502749898");
  });
});

describe("normalizePhoneNumber — təxmin etmir, rədd edir", () => {
  // Kök səbəb məhz "əlimizdən gələni düzəldək" yanaşması idi.
  const rejected: [string, string][] = [
    ["", "empty"],
    ["   ", "empty"],
    ["994502749898", "missing-plus"],
    ["0502749898", "missing-plus"],
    ["+994abc749898", "non-digit"],
    ["+9945", "too-short"],
    ["+9945027498981234567", "too-long"],
  ];
  for (const [input, reason] of rejected) {
    test(`rədd edilir (${reason}): ${JSON.stringify(input)}`, () => {
      assert.throws(
        () => normalizePhoneNumber(input),
        (e: unknown) => e instanceof InvalidPhoneNumberError && e.reason === reason,
      );
    });
  }

  test("İKİ FƏRQLİ prefiks birləşdirilmir — bu, təxmin olardı", () => {
    // `+994+905321234567` hansının doğru olduğunu bilmək mümkün deyil.
    // Uzunluq həddinə düşürsə rədd edilir, düşmürsə olduğu kimi qalır —
    // amma heç bir halda biri "seçilmir".
    assert.throws(() => normalizePhoneNumber("+994+905321234567"), InvalidPhoneNumberError);
  });
});

describe("isNormalizedPhoneNumber — audit skriptinin təsnifatı", () => {
  test("pozuq dəyərlər false qaytarır", () => {
    for (const bad of ["+994+994502749898", "+994 50 274 98 98", "994502749898", "", null, undefined, 42]) {
      assert.equal(isNormalizedPhoneNumber(bad), false, String(bad));
    }
  });

  test("artıq normal olan dəyər true qaytarır", () => {
    assert.equal(isNormalizedPhoneNumber("+994502749898"), true);
  });
});
