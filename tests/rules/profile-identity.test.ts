// Kimlik sahələrinin dəyişmə siyasəti — `profile-identity.ts`-in saf
// hissəsi, emulyatorsuz.
//
// Fayl `venue-fees.test.ts` ilə eyni naxışdadır: rəqəmlər həm burada
// iddia edilir, HƏM DƏ mənbə faylı PARSE edilir, ki sabit dəyişəndə test
// səssizcə köhnə rəqəmi təsdiqləməsin.
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  BIRTH_DATE_CHANGES_ALLOWED,
  NAME_COOLDOWN_DAYS,
  USERNAME_COOLDOWN_DAYS,
  USERNAME_PATTERN,
  cooldownRemainingDays,
  deriveNameLower,
} from "../../functions/src/profile-identity.ts";

const SOURCE = readFileSync(new URL("../../functions/src/profile-identity.ts", import.meta.url), "utf8");
const DAY = 24 * 60 * 60 * 1000;

describe("profile-identity — sabitlər mənbə ilə uyğundur", () => {
  test("kuldaun rəqəmləri mənbədə yazıldığı kimidir", () => {
    assert.match(SOURCE, /USERNAME_COOLDOWN_DAYS = 30\b/);
    assert.match(SOURCE, /NAME_COOLDOWN_DAYS = 15\b/);
    assert.match(SOURCE, /BIRTH_DATE_CHANGES_ALLOWED = 1\b/);
    assert.equal(USERNAME_COOLDOWN_DAYS, 30);
    assert.equal(NAME_COOLDOWN_DAYS, 15);
    assert.equal(BIRTH_DATE_CHANGES_ALLOWED, 1);
  });
});

describe("deriveNameLower — Unicode", () => {
  // Məhz bu adlar qaydalar tərəfindəki `.lower()` ilə sınmışdı. Burada
  // Node-un `toLowerCase()`-i tam Unicode olduğu üçün hamısı keçir; test
  // regressiya hasarıdır — kimsə törəməni yenidən qaydalara köçürsə,
  // əvvəlcə bunu görməlidir.
  const cases: Array<[string, string, string]> = [
    ["Rasim", "Agayev", "rasim agayev"],
    ["Əli", "Məmmədov", "əli məmmədov"],
    ["Ülvi", "Çobanov", "ülvi çobanov"],
    ["Günel", "Öztürk", "günel öztürk"],
    ["Şəhla", "Ğəniyeva", "şəhla ğəniyeva"],
  ];
  for (const [first, last, expected] of cases) {
    test(`${first} ${last} → ${expected}`, () => {
      assert.equal(deriveNameLower(first, last), expected);
    });
  }

  test("boş soyad artıq boşluq buraxmır", () => {
    assert.equal(deriveNameLower("Əli", ""), "əli");
  });

  test("kənar boşluqlar təmizlənir", () => {
    assert.equal(deriveNameLower("  Əli  ", "  Məmmədov "), "əli     məmmədov");
  });
});

describe("cooldownRemainingDays", () => {
  const now = Date.UTC(2026, 8, 1);

  test("heç vaxt dəyişilməyibsə sərbəstdir", () => {
    assert.equal(cooldownRemainingDays(undefined, NAME_COOLDOWN_DAYS, now), 0);
    assert.equal(cooldownRemainingDays(null, NAME_COOLDOWN_DAYS, now), 0);
  });

  test("kuldaun tam bitibsə sərbəstdir", () => {
    assert.equal(cooldownRemainingDays(now - 15 * DAY, NAME_COOLDOWN_DAYS, now), 0);
    assert.equal(cooldownRemainingDays(now - 30 * DAY, USERNAME_COOLDOWN_DAYS, now), 0);
  });

  test("yeni dəyişiklikdən sonra tam müddət qalır", () => {
    assert.equal(cooldownRemainingDays(now, NAME_COOLDOWN_DAYS, now), 15);
    assert.equal(cooldownRemainingDays(now, USERNAME_COOLDOWN_DAYS, now), 30);
  });

  test("YUXARI yuvarlaqlaşdırır — «0 gün qalıb» deyib rədd etmir", () => {
    // 14 gün 1 saat keçib: qalan 23 saatdır, mesaj «1 gün» deməlidir.
    const remaining = cooldownRemainingDays(now - (14 * DAY + 3600_000), NAME_COOLDOWN_DAYS, now);
    assert.equal(remaining, 1);
    assert.ok(remaining > 0, "yazı rədd edilirsə mesaj sıfır gün deməməlidir");
  });

  test("saat geriyə getsə mənfi gün qaytarmır", () => {
    assert.equal(cooldownRemainingDays(now + 5 * DAY, NAME_COOLDOWN_DAYS, now), 20);
  });
});

describe("USERNAME_PATTERN", () => {
  test("latın hərf/rəqəm/nöqtə/alt xətt qəbul edir", () => {
    for (const ok of ["rasim", "user.name", "a_b_c", "abc", "a".repeat(20)]) {
      assert.ok(USERNAME_PATTERN.test(ok), ok);
    }
  });

  test("qısa, uzun və qeyri-ASCII rədd edilir", () => {
    // Qeyri-ASCII qəsdən qadağandır: `usernames/{id}` sənəd id-si
    // kiçildilmiş handle-dır və `firestore.rules` onu hələ də `.lower()`
    // ilə həll edir — ASCII olmayan handle iki tərəfdə fərqli kiçilərdi.
    for (const bad of ["ab", "a".repeat(21), "əli", "İlqar", "ad soyad", "user-name", "user@x"]) {
      assert.ok(!USERNAME_PATTERN.test(bad), bad);
    }
  });
});
