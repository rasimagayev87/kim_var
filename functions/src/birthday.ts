/**
 * Deciding whether a stored `birthDate` falls on a given calendar day
 * in Azerbaijan.
 *
 * ── The bug this fixes ─────────────────────────────────────────────
 *
 * `computeBirthdayMatches` compared the birth date's **UTC** month/day
 * against **Asia/Baku's** today:
 *
 *     const bd = birthDate.toDate();
 *     const bdMonth = String(bd.getUTCMonth() + 1).padStart(2, "0");
 *     const bdDay   = String(bd.getUTCDate()).padStart(2, "0");
 *
 * The client stores what `showDatePicker` returns — LOCAL midnight —
 * so a birthday picked in Baku is written as the previous evening in
 * UTC. Confirmed against a real document: `July 7, 1987 00:00 UTC+5`
 * is stored as `1987-07-06T19:00:00Z`, and `getUTCDate()` therefore
 * answered 6. Every birthday notification went out a day early.
 *
 * ── Why the offset cannot be subtracted ────────────────────────────
 *
 * The obvious repair — add four hours, or add the zone offset — is
 * wrong, and the example above is exactly why. Azerbaijan observed
 * UTC+5 in July 1987 (summer time, and the union-wide "decree time"
 * era); it observes UTC+4 today and no longer keeps DST at all. The
 * correction therefore depends on the BIRTH YEAR, not on today's
 * offset, and a person born in 1987 needs a different shift than one
 * born in 2001.
 *
 * `Intl.DateTimeFormat` with an IANA zone resolves each instant against
 * the historical rules in the ICU database, so it gets 1987 and 2001
 * both right without this file knowing anything about either. That is
 * the whole reason to format rather than arithmetic.
 *
 * No SDK imports, so `tests/rules/birthday.test.ts` can assert the
 * historical cases directly.
 */

/** The one zone this product runs on — the same string
 * `computeBirthdayMatches` already uses for "today" and for its
 * `onSchedule` timeZone. */
export const APP_TIME_ZONE = "Asia/Baku";

const MONTH_DAY_FORMAT = new Intl.DateTimeFormat("en-CA", {
  timeZone: APP_TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/**
 * `MM-DD` for [date] as it was (or will be) read on a calendar in
 * Azerbaijan — historical zone rules included.
 */
export function bakuMonthDay(date: Date): string {
  const parts = MONTH_DAY_FORMAT.formatToParts(date);
  const month = parts.find((p) => p.type === "month")?.value ?? "";
  const day = parts.find((p) => p.type === "day")?.value ?? "";
  return `${month}-${day}`;
}

/** Full `YYYY-MM-DD` in Baku — used for the daily match document id. */
export function bakuDateKey(date: Date): string {
  const parts = MONTH_DAY_FORMAT.formatToParts(date);
  const year = parts.find((p) => p.type === "year")?.value ?? "";
  return `${year}-${bakuMonthDay(date)}`;
}

/** The `YYYY` a moment falls in, read in Baku. */
function bakuYear(date: Date): number {
  return Number(bakuDateKey(date).slice(0, 4));
}

/** Proleptic Gregorian leap year. */
function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

/**
 * Whether [birthDate] falls on the same calendar day-of-year as [today],
 * both read in Baku.
 *
 * ── 29 February ────────────────────────────────────────────────────
 *
 * In a non-leap year a 29-February birthday is observed on **28
 * February**. This is a product decision, made explicitly rather than
 * fallen into: the alternatives were to skip the birthday entirely in
 * three years out of four — which is the one outcome nobody wants,
 * since the person still has a birthday — or to move it to 1 March,
 * which pushes it into a different month and reads as wrong to the
 * person receiving it. 28 February keeps it in the month they were
 * born.
 *
 * Only the non-leap case is remapped. In a leap year 29 February is
 * itself, and someone born on 28 February is unaffected either way —
 * the two never collide, because in a leap year the 29-February
 * birthday matches 29 February and in a non-leap year there is no 29
 * February for anyone else to match.
 */
export function isBirthdayToday(birthDate: Date, today: Date): boolean {
  const born = bakuMonthDay(birthDate);
  const todayMd = bakuMonthDay(today);

  if (born === "02-29" && !isLeapYear(bakuYear(today))) {
    return todayMd === "02-28";
  }
  return born === todayMd;
}
