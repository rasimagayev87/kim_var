/**
 * The moderation queue's 13:00 badge
 * (`admin-panel/src/lib/birthday-deadline.ts`).
 *
 * The whole birthday flow depends on a campaign being approved before
 * 13:00, and the only thing telling a moderator that is this badge. The
 * timezone is the part worth pinning: computed in UTC the deadline
 * lands four hours late, the badge stays green past 13:00 Baku, and
 * nobody finds out until a real birthday is missed.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  BIRTHDAY_PUBLISH_HOUR,
  bakuDateKey,
  birthdayDeadlineState,
  dateKeyFromMatchId,
  formatBirthdayDeadline,
  publishDeadlineMs,
} from "../../admin-panel/src/lib/birthday-deadline";

describe("match id → tarix açarı", () => {
  test("`{tarix}_{venueId}` formatından tarixi çıxarır", () => {
    assert.equal(dateKeyFromMatchId("2026-08-31_venue123"), "2026-08-31");
  });

  test("uyğun olmayan dəyərlər null qaytarır", () => {
    for (const value of [null, undefined, "", "venue123", "2026-08_venue", "31-08-2026_v"]) {
      assert.equal(dateKeyFromMatchId(value), null, `${value}`);
    }
  });
});

describe("13:00 kəsimi Bakı vaxtı ilə hesablanır", () => {
  test("13:00 Bakı = 09:00 UTC", () => {
    // Bu, bütün modulun mahiyyətidir. UTC-də hesablansaydı kəsim dörd
    // saat gec düşərdi.
    assert.equal(publishDeadlineMs("2026-08-31"), Date.parse("2026-08-31T09:00:00Z"));
  });

  test("bugünkü tarix açarı Bakıya görə oxunur", () => {
    // UTC 20:30 = Bakıda ertəsi gün 00:30.
    assert.equal(bakuDateKey(new Date("2026-08-30T20:30:00Z")), "2026-08-31");
    assert.equal(bakuDateKey(new Date("2026-08-30T19:30:00Z")), "2026-08-30");
  });
});

describe("nişanın vəziyyəti", () => {
  const TODAY = "2026-08-31";
  const matchId = `${TODAY}_venue123`;

  test("ad günü kampaniyası olmayan sətir üçün nişan yoxdur", () => {
    const state = birthdayDeadlineState(null, new Date("2026-08-31T08:00:00Z"));
    assert.deepEqual(state, { kind: "none" });
    assert.equal(formatBirthdayDeadline(state), null);
  });

  test("başqa günün eşleşməsi bugünkü növbəni zibilləmir", () => {
    assert.deepEqual(
      birthdayDeadlineState("2026-08-30_venue123", new Date("2026-08-31T08:00:00Z")),
      { kind: "none" },
    );
  });

  test("12:30 Bakı → 30 dəqiqə qalır", () => {
    const state = birthdayDeadlineState(matchId, new Date("2026-08-31T08:30:00Z"));
    assert.deepEqual(state, { kind: "pending", minutesLeft: 30 });
    assert.equal(formatBirthdayDeadline(state), `🎂 Ad günü — ${BIRTHDAY_PUBLISH_HOUR}:00-a 30 dəqiqə`);
  });

  test("11:00 Bakı → saat + dəqiqə kimi göstərilir", () => {
    const state = birthdayDeadlineState(matchId, new Date("2026-08-31T07:00:00Z"));
    assert.equal(formatBirthdayDeadline(state), `🎂 Ad günü — ${BIRTHDAY_PUBLISH_HOUR}:00-a 2 saat 0 dəqiqə`);
  });

  test("son 30 saniyə `0 dəqiqə` yox, `1 dəqiqə` yazır", () => {
    const state = birthdayDeadlineState(matchId, new Date("2026-08-31T08:59:30Z"));
    assert.deepEqual(state, { kind: "pending", minutesLeft: 1 });
  });

  test("13:00-dan sonra `missed`, amma itirilmiş kimi yazılmır", () => {
    // Mətn vacibdir: kampaniya hələ də təsdiqdə dərhal yayımlanır
    // (`publishLateBirthdayOfferIfNeeded`), yerləşdirmə haqqı ödənilib.
    // "Gec qaldı" yazsaydıq moderator təsdiqləməyi mənasız sayardı.
    const state = birthdayDeadlineState(matchId, new Date("2026-08-31T09:00:01Z"));
    assert.deepEqual(state, { kind: "missed" });
    assert.match(formatBirthdayDeadline(state)!, /dərhal yayımlanır/);
  });

  test("tam 13:00:00 artıq keçmiş sayılır", () => {
    assert.deepEqual(birthdayDeadlineState(matchId, new Date("2026-08-31T09:00:00Z")), { kind: "missed" });
  });
});

describe("server ilə paritet", () => {
  test("nəşr saatı funksiyalardakı ilə eynidir", async () => {
    const { readFileSync } = await import("node:fs");
    const src = readFileSync(new URL("../../functions/src/index.ts", import.meta.url), "utf8");
    const match = /const BIRTHDAY_PUBLISH_HOUR = (\d+);/.exec(src);
    assert.ok(match, "functions/src/index.ts-də BIRTHDAY_PUBLISH_HOUR tapılmadı");
    // İki nüsxə, çünki admin panel TypeScript-i funksiyalardan import
    // edə bilmir — eyni quruluş `venue-categories`/`media-paths`-dakı
    // kimi, və onları uyğun saxlayan yeganə şey bu testdir.
    assert.equal(Number(match[1]), BIRTHDAY_PUBLISH_HOUR);
  });
});
