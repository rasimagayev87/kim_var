/**
 * Nightly per-venue statistics — the collection layer for the monthly
 * report venues will get after launch.
 *
 * ── Why this exists before the report does ─────────────────────────
 *
 * `audienceHistory` is swept to a 7-day rolling window
 * (`AUDIENCE_HISTORY_RETENTION_MS`). Everything older is gone and
 * cannot be reconstructed. A monthly report built after launch would
 * therefore open with an empty first month, and every month before the
 * rollup started would stay empty forever. Collection has to lead the
 * feature that consumes it.
 *
 * ── What this module is ───────────────────────────────────────────
 *
 * Arithmetic over plain objects, no SDK, so `tests/rules/daily-stats.test.ts`
 * can assert the privacy rules directly. Those are the parts that
 * would fail silently: a k-anonymity floor that returns 0 instead of
 * null, or a schema that quietly grows a `uid` field, breaks a promise
 * made in the privacy policy without breaking a build.
 */

/** The k-anonymity floor. Deliberately imported from `geo.ts` rather
 * than redeclared — one threshold, one definition. */
import { VENUE_AUDIENCE_MIN_REPORTABLE_COUNT } from "./geo";

export { VENUE_AUDIENCE_MIN_REPORTABLE_COUNT };

/**
 * How long a daily document survives — 400 days.
 *
 * Not 90. The single most valuable line in a monthly report is "the
 * same month last year": in hospitality, seasonality is the dominant
 * signal, and a venue owner comparing August to July learns much less
 * than one comparing August to last August. 400 days covers a full
 * year plus the slack needed to generate the report that reads it.
 *
 * Removed by a native TTL policy on `expiresAt`, the same arrangement
 * as `notificationIntents` and `birthdayFeed` — a structure that
 * cannot accumulate, rather than another cleanup job to forget.
 */
export const DAILY_STATS_RETENTION_DAYS = 400;

/**
 * `YYYY-MM-DD` in UTC.
 *
 * UTC, not venue-local time, and this is a real trade-off rather than
 * an oversight. Azerbaijan is UTC+4, so a "day" here ends at 04:00
 * local — a restaurant's late evening lands in the previous UTC day
 * and its peak hour is reported in UTC. For month-over-month
 * comparison that is harmless, because every day is shifted
 * identically and the comparison is against the venue's own history.
 * It matters only if a report ever states an absolute clock time to
 * the owner, at which point the hour must be converted for display —
 * see `audiencePeakHour`.
 */
export function dailyStatsDateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** The key for the day before [date] — what a run just after midnight
 * is actually summarising. */
export function previousDateKey(date: Date): string {
  return dailyStatsDateKey(new Date(date.getTime() - 24 * 60 * 60 * 1000));
}

/**
 * A count that is safe to report, or `null`.
 *
 * ── null, never 0 ─────────────────────────────────────────────────
 *
 * Below the floor this returns `null`, and the distinction from `0`
 * carries the whole meaning: "fewer than five people were around" and
 * "nobody was around" are different facts, and collapsing them would
 * both mislead the owner and, over a run of days, leak the suppressed
 * value — a month of `0`s with one `7` says more about the small days
 * than a month of `null`s does.
 *
 * `reportableAudienceCount` in index.ts floors to 0 for the LIVE
 * counter, and that is correct there: a client renders no card at 0,
 * and a nullable field would just become 0 at the render site anyway.
 * Here the value is stored rather than drawn, so the honest gap is
 * available and worth keeping.
 */
export function reportableOrNull(count: number | null | undefined): number | null {
  if (typeof count !== "number" || !Number.isFinite(count)) return null;
  return count < VENUE_AUDIENCE_MIN_REPORTABLE_COUNT ? null : count;
}

/** One `audienceHistory` sample, or one 15-minute tick accumulated
 * into `private/counters`. */
export interface AudienceSample {
  count: number;
  hour: number;
}

export interface AudienceAggregate {
  /** Mean across the day's samples, rounded. `null` below the floor. */
  audienceAvg: number | null;
  /** The highest single sample. `null` below the floor. */
  audiencePeak: number | null;
  /** UTC hour (0-23) the peak fell in, or `null` when there is no
   * reportable peak — an hour with no count attached would point at a
   * time of day while refusing to say what happened then. */
  audiencePeakHour: number | null;
  /** How many 15-minute samples the day actually produced. NOT floored:
   * this describes the measurement, not the people, and a report needs
   * it to distinguish "quiet day" from "the scheduler was down". */
  audienceSamples: number;
}

/**
 * The day's samples reduced to four numbers.
 *
 * The floor is applied to the OUTPUT, not to each sample: averaging
 * floored samples would bias the mean upward, since every suppressed
 * value would have to be treated as something. The raw mean is
 * computed and then suppressed as a whole if it is too small to
 * report.
 *
 * Ties on the peak keep the EARLIEST hour, so a day with two equal
 * maxima reports the same hour on a re-run.
 */
export function aggregateAudienceSamples(samples: readonly AudienceSample[]): AudienceAggregate {
  const usable = samples.filter(
    (s) => typeof s.count === "number" && Number.isFinite(s.count) &&
      typeof s.hour === "number" && s.hour >= 0 && s.hour <= 23,
  );
  if (usable.length === 0) {
    return { audienceAvg: null, audiencePeak: null, audiencePeakHour: null, audienceSamples: 0 };
  }

  let sum = 0;
  let peak = usable[0].count;
  let peakHour = usable[0].hour;
  for (const s of usable) {
    sum += s.count;
    if (s.count > peak) {
      peak = s.count;
      peakHour = s.hour;
    }
  }

  const avg = reportableOrNull(Math.round(sum / usable.length));
  const reportablePeak = reportableOrNull(peak);
  return {
    audienceAvg: avg,
    audiencePeak: reportablePeak,
    // The hour is only meaningful alongside a peak we are willing to
    // state. Publishing "the busiest hour was 21:00" while suppressing
    // the count still says a specific person was there at 21:00.
    audiencePeakHour: reportablePeak === null ? null : peakHour,
    audienceSamples: usable.length,
  };
}

/**
 * Every field a `dailyStats` document may contain.
 *
 * ── This list IS the privacy guarantee ────────────────────────────
 *
 * The privacy policy says these documents hold aggregate numbers and
 * nothing that identifies a person. Nothing in TypeScript enforces
 * that — a `uid` added here in six months would compile. So the
 * allowlist is asserted by `tests/rules/daily-stats.test.ts`, which
 * fails on any field it does not recognise and on anything that looks
 * like an identifier.
 */
export const DAILY_STATS_FIELDS: readonly string[] = [
  "date",
  "audienceAvg", "audiencePeak", "audiencePeakHour", "audienceSamples",
  "checkins",
  "waitlistJoined", "waitlistSeated",
  "likes",
  "reviews", "reviewAvgRating",
  "offerRedemptions",
  "pinboxSold", "pinboxRedeemed", "pinboxUnclaimed", "pinboxGrossAmount",
  "eventsCreated",
  "boostActive",
  "freeCampaignsUsed", "freeEventsUsed",
  "computedAt", "expiresAt",
];

/** Substrings that must never appear in a field name here. A daily
 * rollup that grows one of these has stopped being an aggregate. */
export const FORBIDDEN_STATS_FIELD_PATTERNS: readonly string[] = [
  "uid", "userId", "email", "phone", "name", "lat", "lng", "location", "ids",
];
