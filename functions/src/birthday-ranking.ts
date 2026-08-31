/**
 * Choosing which venues a birthday user hears about at 13:00.
 *
 * ── Where this sits in the flow ────────────────────────────────────
 *
 *   11:00  computeBirthdayMatches   owners are told "N people nearby
 *                                   have a birthday today"
 *   11:00–13:00                     THE MODERATION WINDOW — the owner
 *                                   creates a campaign and a moderator
 *                                   approves it
 *   13:00  publishBirthdayCampaigns everything approved in that window
 *                                   is published at once, and this
 *                                   module decides the order
 *
 * The two-hour gap is the design, not a delay to route around. It
 * follows that the candidate pool here is NARROW: only venues that
 * created a birthday campaign today AND got it approved. It is not
 * every venue eligible for the birthday feature. A venue that did
 * nothing today is not ranked last, it is absent.
 *
 * ── Why a pure module ──────────────────────────────────────────────
 *
 * Weights are the kind of thing that gets "tidied" — a 0.4 becomes a
 * 0.5, a clamp disappears, and nothing fails. Everything here is
 * arithmetic over plain objects, so `tests/rules/birthday-ranking.test.ts`
 * asserts the weights sum to 1, that each dimension is monotone, and
 * that the distinct-category rule holds. No SDK imports.
 */

/**
 * The four signals and their weights, fixed by product decision:
 * proximity 40%, richness 30%, campaigns 20%, boost 10%.
 *
 * ── Why integer percentages and not 0.4/0.3/0.2/0.1 ────────────────
 *
 * Written as fractions these do not sum to one. `0.4 + 0.3 + 0.2 +
 * 0.1` is `0.9999999999999999` in IEEE-754, so a venue at every
 * ceiling would score fractionally under 1 and the "weights sum to
 * 1" invariant could not be asserted at all — only approximated.
 *
 * Held as integers out of [BIRTHDAY_WEIGHT_TOTAL] the sum is exact,
 * the maximum score is exactly 1, and each dimension's contribution
 * is exactly its stated share. The single division happens once, at
 * the end, instead of accumulating four times.
 *
 * `tests/rules/birthday-ranking.test.ts` asserts the sum — a score is
 * only comparable across users if the scale is the same for everyone.
 */
export const BIRTHDAY_WEIGHTS = {
  /** How close the venue is, relative to the user's own chosen reach. */
  proximity: 40,
  /** How many DISTINCT kinds of thing the venue has live. */
  richness: 30,
  /** How many live approved offers the venue has — volume. */
  campaigns: 20,
  /** Whether the venue paid to be boosted. */
  boost: 10,
} as const;

/** The weights are percentages; a perfect candidate scores exactly 1. */
export const BIRTHDAY_WEIGHT_TOTAL = 100;

/**
 * Reach used for the proximity score when the user has not restricted
 * themselves to a distance — `country`, `world`, or no mode at all.
 *
 * Without a fallback the proximity term would be undefined for exactly
 * the users who set the widest reach, and they would score every venue
 * identically. 30 km is the largest distance chip the Discover picker
 * offers (`kRadiusOptionsKm`), so it is the widest reach the product
 * ever treats as "nearby".
 */
export const PROXIMITY_DEFAULT_REACH_M = 30000;

/** Content kinds counted by [richness]: offer, event, PinBox. */
export const RICHNESS_TYPES = 3;

/**
 * Where the campaign-count score saturates.
 *
 * Five live offers and fifty live offers are the same signal — "this
 * venue is active". Without a cap one venue with a large catalogue
 * would dominate the ranking for every user regardless of distance,
 * which is the opposite of what a birthday feed is for.
 */
export const ACTIVE_CAMPAIGN_CAP = 5;

/** How many venues the 13:00 notification names. */
export const BIRTHDAY_HIGHLIGHT_COUNT = 3;

/** How many venues the "Ad günü fürsətləri" list holds. */
export const BIRTHDAY_FEED_MAX = 10;

/** One ranked candidate: a venue that published a birthday campaign
 * today, measured against ONE user. */
export interface BirthdayVenueCandidate {
  venueId: string;
  category: string;
  /** Metres from the user to the venue. */
  distanceMeters: number;
  /** The user's own reach in metres, or `undefined` for unrestricted —
   * see [PROXIMITY_DEFAULT_REACH_M]. */
  reachMeters?: number;
  /** How many of {offer, event, pinbox} the venue has live right now. */
  liveContentTypes: number;
  /** Live approved offers at this venue. */
  activeCampaigns: number;
  /** Any offer with `boostedUntil` still in the future. */
  boosted: boolean;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(1, Math.max(0, value));
}

/**
 * The weighted score in [0, 1].
 *
 * ── Why richness and campaigns are BOTH here ───────────────────────
 *
 * They overlap: a live offer counts toward both. That is deliberate
 * and must not be "simplified" away. They measure different things —
 * richness is VARIETY (does this venue offer more than one kind of
 * thing?), campaigns is VOLUME (how much is running?). A cinema with
 * one offer, one event and one PinBox and a restaurant with five
 * offers are genuinely different propositions for someone deciding
 * where to spend their birthday, and collapsing the two into a single
 * count would make them indistinguishable.
 *
 * Note what `campaigns` counts: the venue's live approved offers, ALL
 * of them, not its birthday campaigns. Within this pool almost every
 * venue has exactly one birthday campaign — counting those would make
 * the term a constant and the 20% weight would silently do nothing.
 */
export function scoreVenue(candidate: BirthdayVenueCandidate): number {
  const reach = candidate.reachMeters ?? PROXIMITY_DEFAULT_REACH_M;
  // A zero or negative reach would divide by zero; treat it as "no
  // usable proximity signal" rather than propagating NaN into a sort.
  const proximity = reach > 0 ? 1 - clamp01(candidate.distanceMeters / reach) : 0;
  const richness = clamp01(candidate.liveContentTypes / RICHNESS_TYPES);
  const campaigns = clamp01(candidate.activeCampaigns / ACTIVE_CAMPAIGN_CAP);
  const boost = candidate.boosted ? 1 : 0;

  return (
    (BIRTHDAY_WEIGHTS.proximity * proximity +
      BIRTHDAY_WEIGHTS.richness * richness +
      BIRTHDAY_WEIGHTS.campaigns * campaigns +
      BIRTHDAY_WEIGHTS.boost * boost) /
    BIRTHDAY_WEIGHT_TOTAL
  );
}

/** A candidate with its score, as produced by [rankCandidates]. */
export interface ScoredBirthdayVenue extends BirthdayVenueCandidate {
  score: number;
}

/**
 * Every candidate scored, best first.
 *
 * Ties break on distance, then on `venueId`. The last one matters:
 * without it two venues with identical scores could swap places
 * between runs, so a retry of the same day would produce a different
 * feed and a different notification body for no reason.
 */
export function rankCandidates(candidates: readonly BirthdayVenueCandidate[]): ScoredBirthdayVenue[] {
  return candidates
    .map((c) => ({ ...c, score: scoreVenue(c) }))
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (a.distanceMeters !== b.distanceMeters) return a.distanceMeters - b.distanceMeters;
      return a.venueId < b.venueId ? -1 : a.venueId > b.venueId ? 1 : 0;
    });
}

/**
 * The highest-scoring venue from each of up to [limit] DISTINCT
 * categories.
 *
 * A birthday feed of three restaurants is one suggestion repeated
 * three times. Taking the best of each category instead gives the
 * person an actual choice — eat, or watch something, or be pampered.
 *
 * Returns FEWER than [limit] when fewer categories are represented,
 * and deliberately does NOT top up with a second venue from a category
 * already used: two entries from one category would be exactly the
 * repetition this rule exists to prevent. One good option beats three
 * near-identical ones.
 *
 * Input is expected pre-sorted by [rankCandidates]; this walks it once
 * and keeps the first occurrence of each category.
 */
export function pickDistinctCategoryVenues<T extends { category: string }>(
  ranked: readonly T[],
  limit: number = BIRTHDAY_HIGHLIGHT_COUNT,
): T[] {
  const seen = new Set<string>();
  const picked: T[] = [];
  for (const candidate of ranked) {
    if (picked.length >= limit) break;
    if (seen.has(candidate.category)) continue;
    seen.add(candidate.category);
    picked.push(candidate);
  }
  return picked;
}
