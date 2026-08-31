/**
 * The 13:00 deadline a birthday campaign has to clear.
 *
 * ── Why the moderation queue needed this at all ────────────────────
 *
 * The birthday flow is the only thing in this product with a hard
 * same-day deadline:
 *
 *   11:00  the venue owner is told people nearby have a birthday
 *   11:00–13:00  they write a campaign and a moderator approves it
 *   13:00  `publishBirthdayCampaigns` publishes everything approved by
 *          then, and each birthday user gets one notification
 *
 * Until this existed the offers queue sorted by `createdAt` and showed
 * nothing but a status badge, so a birthday campaign was visually
 * identical to an ordinary pending offer with a week of slack. The
 * entire flow depended on a moderator happening to look at the right
 * row before 13:00, with nothing on screen saying so.
 *
 * A deadline nobody can see is not a deadline.
 *
 * No React and no Firestore imports, so `tests/rules/birthday-deadline.test.ts`
 * can assert the arithmetic — particularly the timezone, which is the
 * part that would be wrong in a way nobody notices until a real
 * birthday is missed.
 */

/** The hour, in Baku, when campaigns publish — mirrors
 * `BIRTHDAY_PUBLISH_HOUR` in `functions/src/index.ts`. */
export const BIRTHDAY_PUBLISH_HOUR = 13;

/**
 * Azerbaijan's fixed offset. Real, not an approximation: DST was
 * abolished in 2016 and the country has been a flat UTC+4 since.
 *
 * The Cloud Function deliberately does NOT take this shortcut — it also
 * reads birth dates from the 1980s, when the offset was different, so
 * it formats against the IANA zone instead (`functions/src/birthday.ts`).
 * Here the only dates in play are today's and tomorrow's, where the
 * fixed offset is exact.
 */
const BAKU_UTC_OFFSET_HOURS = 4;

/** `{YYYY-MM-DD}_{venueId}` → `YYYY-MM-DD`, or null if it is not a
 * match id at all. */
export function dateKeyFromMatchId(matchId: string | null | undefined): string | null {
  if (!matchId) return null;
  const match = /^(\d{4}-\d{2}-\d{2})_/.exec(matchId);
  return match ? match[1] : null;
}

/** The instant a campaign for [dateKey] stops being publishable with
 * everything else, as epoch milliseconds. */
export function publishDeadlineMs(dateKey: string): number {
  return Date.parse(`${dateKey}T${String(BIRTHDAY_PUBLISH_HOUR - BAKU_UTC_OFFSET_HOURS).padStart(2, "0")}:00:00Z`);
}

/** Today in Baku, as the `YYYY-MM-DD` key `birthdayMatches` uses. */
export function bakuDateKey(now: Date = new Date()): string {
  const shifted = new Date(now.getTime() + BAKU_UTC_OFFSET_HOURS * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

export type BirthdayDeadlineState =
  | { kind: "none" }
  | { kind: "pending"; minutesLeft: number }
  | { kind: "missed" };

/**
 * What the queue should say about one offer.
 *
 * `none`    — not a birthday campaign, or one from another day.
 * `pending` — still publishable; [minutesLeft] is what the badge shows.
 * `missed`  — 13:00 has passed. NOT the same as "lost": the campaign
 *             still publishes on approval, silently, because the
 *             birthday is still today and the placement fee is already
 *             paid (see `publishLateBirthdayOfferIfNeeded`). The badge
 *             says so rather than implying the work is wasted, which
 *             would be both wrong and a reason to stop bothering.
 */
export function birthdayDeadlineState(
  matchId: string | null | undefined,
  now: Date = new Date(),
): BirthdayDeadlineState {
  const dateKey = dateKeyFromMatchId(matchId);
  if (dateKey === null) return { kind: "none" };
  if (dateKey !== bakuDateKey(now)) return { kind: "none" };

  const remainingMs = publishDeadlineMs(dateKey) - now.getTime();
  if (remainingMs <= 0) return { kind: "missed" };
  // Rounded UP: with 30 seconds left "1 dəqiqə" is honest and "0
  // dəqiqə" reads as already over.
  return { kind: "pending", minutesLeft: Math.ceil(remainingMs / 60000) };
}

/** The badge text. Minutes below an hour, hours and minutes above it —
 * "127 dəqiqə" is a number a reader has to convert. */
export function formatBirthdayDeadline(state: BirthdayDeadlineState): string | null {
  if (state.kind === "none") return null;
  if (state.kind === "missed") return `🎂 Ad günü — ${BIRTHDAY_PUBLISH_HOUR}:00 keçib, təsdiqdə dərhal yayımlanır`;
  const { minutesLeft } = state;
  if (minutesLeft < 60) return `🎂 Ad günü — ${BIRTHDAY_PUBLISH_HOUR}:00-a ${minutesLeft} dəqiqə`;
  const hours = Math.floor(minutesLeft / 60);
  const minutes = minutesLeft % 60;
  return `🎂 Ad günü — ${BIRTHDAY_PUBLISH_HOUR}:00-a ${hours} saat ${minutes} dəqiqə`;
}
