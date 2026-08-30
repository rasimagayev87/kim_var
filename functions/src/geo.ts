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
 */
export function bucketDistanceMeters(meters: number): number {
  return Math.max(
    NEARBY_DISTANCE_BUCKET_METERS,
    Math.round(meters / NEARBY_DISTANCE_BUCKET_METERS) * NEARBY_DISTANCE_BUCKET_METERS,
  );
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
