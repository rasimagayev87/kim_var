/**
 * Location-privacy arithmetic, kept free of any SDK import so it can be
 * asserted directly.
 *
 * These four rules ARE the H-1/H-2 fixes. Until now they lived inline
 * in `index.ts`, where nothing tested them — the self-verification pass
 * on 2026-08-30 found that every other P0 fix had a regression test and
 * these two did not, purely because `index.ts` cannot be imported
 * without the Firebase Admin SDK. The same extraction was already done
 * for `chat-media.ts` and `phone.ts`; this closes the pattern.
 *
 * Worth being explicit about why that matters here specifically: a
 * k-anonymity floor and a distance quantizer are both a single
 * comparison. Either one can be deleted, inverted, or "simplified" in a
 * later edit without anything looking obviously broken, and the result
 * would be a silent regression in exactly the direction that leaks
 * people's locations.
 */

/** Distance answers are rounded to this, and never report closer. */
export const NEARBY_DISTANCE_BUCKET_METERS = 100;

/** Audience counts below this report as 0 rather than as themselves. */
export const VENUE_AUDIENCE_MIN_REPORTABLE_COUNT = 5;

/** Owner-set audience radius is capped here regardless of what was asked. */
export const VENUE_AUDIENCE_MAX_RADIUS_KM = 50;

/** Above this implied speed between two nearby queries, the second is refused. */
export const NEARBY_MAX_PLAUSIBLE_SPEED_KMH = 300;

/** Two probes further apart in time than this are not compared at all. */
export const NEARBY_PROBE_WINDOW_MS = 15 * 60 * 1000;

export function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const earthRadiusMeters = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(a));
}

/**
 * P0 / H-1 (a) — quantizes a distance before it leaves the server.
 *
 * The floor is the point, not the rounding: an honest `Math.round` of
 * 12 m is 0 m, and "0 m away" reads as "standing next to you", which is
 * both the most sensitive answer and one this must never give. So
 * everything within ~150 m reports as 100 m.
 *
 * ── READ THIS BEFORE TOUCHING [quantizeOriginDegrees] ──────────────
 *
 * This function is NOT what stops trilateration, and an earlier
 * version of this comment claimed that it was. The claim was wrong and
 * it is worth knowing exactly why, because the wrong version is the
 * intuitive one.
 *
 * Rounding the ANSWER coarsens what one reply says. It does nothing
 * about how precisely an attacker can locate the boundary BETWEEN two
 * answers — and the boundary is the leak. `Math.round(d/100)*100`
 * flips from 100 to 200 at exactly d = 150 m, and that flip is a sharp,
 * deterministic, noiseless function of the caller's own position. The
 * caller controls that position (`users/{uid}/private/data.lat/lng` is
 * client-written by design, and locking it would achieve nothing — a
 * rooted device spoofs GPS below the app). So the attacker does not
 * read a distance at all; they binary-search their OWN coordinates for
 * the flip, which pins the target to a 150 m circle to whatever
 * precision they care to spend calls on. Three such circles from three
 * directions intersect at a point.
 *
 * Measured against this exact code: 30 calls, 0.13 m final error.
 * Neither existing guard interferes — [isPlausibleMovement]'s 300 km/h
 * allows ~500 m of movement between calls six seconds apart while the
 * search steps are ~100 m, and 30 calls at 10/60 s is three minutes.
 *
 * Two fixes that look right and are not:
 *   - COARSER BUCKETS (bands like "<1 km", "1-3 km"). Moves the
 *     boundary; does not remove it. Measured: 38 calls, 0.06 m.
 *   - A DETERMINISTIC PER-PAIR JITTER added to the distance. It is
 *     constant for a given (viewer, target, day), so it is not an
 *     unknown that averaging could remove — but the attack never
 *     averages. A constant offset is simply a third unknown alongside
 *     the target's x and y, and three unknowns fall out of four
 *     circles. This is textbook GPS pseudorange solving with a clock
 *     bias. Measured: 44 calls, 0.09 m.
 *
 * What actually works is quantizing the INPUT — see
 * [quantizeOriginDegrees]. Keep both: this one bounds what a single
 * honest reply discloses, that one removes the boundary to search.
 */
export function bucketDistanceMeters(meters: number): number {
  return Math.max(
    NEARBY_DISTANCE_BUCKET_METERS,
    Math.round(meters / NEARBY_DISTANCE_BUCKET_METERS) * NEARBY_DISTANCE_BUCKET_METERS,
  );
}

/** Degrees of latitude per [NEARBY_DISTANCE_BUCKET_METERS] — the same
 * 100 m ≈ 1/1113.2° step the candidate marker grid already uses. */
const ORIGIN_GRID_STEP_DEG = NEARBY_DISTANCE_BUCKET_METERS / 111320;

/**
 * Snaps a caller-supplied query origin to a fixed ~100 m grid, BEFORE
 * anything is computed from it.
 *
 * This is the actual trilateration fix — see [bucketDistanceMeters]
 * for the measurements showing why output-side rounding is not.
 *
 * The mechanism is simply that the attack needs something continuous
 * to bisect. Once the origin is snapped, moving the claimed position
 * by a metre changes nothing at all: the whole query is a function of
 * the grid cell, so the response is constant across each cell and
 * there is no boundary to converge on. What an attacker can still do
 * is sample distinct cells and intersect the resulting annuli, which
 * bottoms out around the grid size — measured at 28 m, and, unlike the
 * 0.13 m above, it does NOT improve with more calls. That is the
 * difference between a bound and a speed bump.
 *
 * Applied to the ORIGIN, this covers every consumer of the distance at
 * once, which matters because the label was never the only channel.
 * In `findNearbyUsers` the raw distance also drove
 * `isWithinNearbyVisibility` (a candidate appearing/disappearing marks
 * their own visibility radius exactly) and the distance sort feeding
 * `NEARBY_RESULT_CAP` (a rank swap marks a perpendicular bisector) —
 * both sharp boundaries in their own right, both of which would have
 * survived any amount of work on the returned number. Fixing the input
 * fixes all three; fixing outputs would have meant finding all three.
 *
 * NOT used for [isPlausibleMovement], which deliberately keeps
 * comparing the RAW claimed positions: its job is spotting a caller
 * who teleports, and quantizing there would only blur the evidence.
 */
export function quantizeOriginDegrees(value: number): number {
  return Math.round(value / ORIGIN_GRID_STEP_DEG) * ORIGIN_GRID_STEP_DEG;
}

/**
 * P0 / H-2 — the k-anonymity floor on a venue's audience preview.
 *
 * A count of 1 or 2 at a known place and time is not a statistic, it is
 * a person. Reports 0 rather than the true number below the threshold.
 */
export function reportableAudienceCount(count: number): number {
  return count < VENUE_AUDIENCE_MIN_REPORTABLE_COUNT ? 0 : count;
}

/** P0 / H-2 — caps a client-supplied radius. */
export function clampAudienceRadiusKm(requestedRadiusKm: number): number {
  return Math.min(requestedRadiusKm, VENUE_AUDIENCE_MAX_RADIUS_KM);
}

/**
 * The only `audienceRadiusKm` values a venue may hold.
 *
 * HAND-SYNCED MIRROR of `kRadiusOptionsKm`
 * (lib/features/location/presentation/providers/location_providers.dart),
 * which is the list the create/edit form's radius picker renders. Same
 * "duplicate list, two runtimes" arrangement as
 * `OFFER_ONLY_VENUE_CATEGORIES` and its `firestore.rules` twin.
 *
 * An ALLOWLIST rather than a min/max range, matching how
 * `previewVenueAudience` already validates `mode`. A range would still
 * accept 0.001 km, and the reason to constrain this field at all is
 * that `submitVenue`/`updateVenue` accepted ANY number: the radius is
 * the one venue field exempt from re-moderation, so an owner calling
 * the callable directly (the picker never offers it) could set a
 * few-metre radius and turn `computeVenueAudienceHistory`'s peak-hour
 * push into a doorway presence sensor. The k-anonymity floor now
 * applied to that notification is the primary fix; this is the second
 * half, and it is what keeps the field's meaning inside what a
 * reviewer would recognise.
 *
 * 0.1 km IS legitimate — it is the picker's first chip. The floor is
 * not what makes a small radius safe; [VENUE_AUDIENCE_MIN_REPORTABLE_COUNT]
 * is.
 *
 * IF `radius_options_json` (Remote Config, read by
 * `applyRemoteRadiusOptions`) EVER CHANGES, THIS LIST MUST CHANGE WITH
 * IT. The parameter is currently absent from
 * `remoteconfig.template.json`, so the Dart default below is what
 * production actually serves. A value the client offers but this list
 * rejects surfaces as a failed edit — loud, and fixable — which is the
 * intended failure direction; silently accepting an unreviewed radius
 * is not.
 */
export const VENUE_AUDIENCE_RADIUS_OPTIONS_KM: readonly number[] = [0.1, 0.5, 1, 5, 10, 30];

/**
 * Whether [value] is one of [VENUE_AUDIENCE_RADIUS_OPTIONS_KM].
 *
 * Compared with a tolerance, not `includes`: these arrive as JSON
 * numbers through a callable, and `0.1` is not exactly representable
 * in binary floating point. An exact-equality check would work today
 * and break the first time a client serialized the value differently.
 */
export function isAllowedVenueAudienceRadiusKm(value: unknown): value is number {
  if (typeof value !== "number" || !Number.isFinite(value)) return false;
  return VENUE_AUDIENCE_RADIUS_OPTIONS_KM.some((allowed) => Math.abs(allowed - value) < 1e-9);
}

/**
 * P0 / H-1 (b) — the decision half of `assertPlausibleMovement`, with
 * the Firestore read/write left behind in `index.ts`.
 *
 * Returns `true` (allow) when there is no usable previous probe: a
 * first-ever query has nothing to compare against, and a probe older
 * than the window tells us nothing, since a person really can be
 * anywhere after 15 minutes.
 */
export function isPlausibleMovement(
  previous: { lat?: unknown; lng?: unknown; at?: unknown } | undefined,
  lat: number,
  lng: number,
  nowMs: number,
): boolean {
  const prevLat = previous?.lat;
  const prevLng = previous?.lng;
  const prevAt = previous?.at;
  if (typeof prevLat !== "number" || typeof prevLng !== "number" || typeof prevAt !== "number") {
    return true;
  }
  const elapsedMs = nowMs - prevAt;
  if (elapsedMs <= 0 || elapsedMs >= NEARBY_PROBE_WINDOW_MS) return true;
  const movedKm = haversineMeters(prevLat, prevLng, lat, lng) / 1000;
  const speedKmh = movedKm / (elapsedMs / 3_600_000);
  return speedKmh <= NEARBY_MAX_PLAUSIBLE_SPEED_KMH;
}
