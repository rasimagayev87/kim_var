/**
 * Turning a day's new listings into at most three notifications per
 * user.
 *
 * ── What this replaces ─────────────────────────────────────────────
 *
 * `notifyNearbyUsersOfNewOffer`/`Event`/`PinBox` each fanned out at
 * creation time: scan up to 1000 `users`, merge each one's
 * `private/data`, then read a per-user throttle document — roughly
 * 3000 reads PER LISTING, and one push per user per listing. The offer
 * path had a 24-hour throttle scoped to the VENUE, so fifty venues
 * meant fifty pushes; the event path had only a per-event dedup, so a
 * venue posting twenty events sent twenty.
 *
 * At 50,000 venues each publishing once a day that is ~150 million
 * reads and, for the user, an uninstall.
 *
 * The digest inverts it. Triggers record an INTENT per listing — one
 * document, no user scan. Once a day this module counts, per user,
 * how many of those fall inside that user's own radius, and emits at
 * most one notification per content type. Cost becomes
 * `O(listings) + O(users)` once a day instead of `O(listings × users)`
 * continuously, and the notification count stops depending on how many
 * venues exist: "5 new campaigns" and "47 new campaigns" are the same
 * single push.
 *
 * ── Why a pure module ──────────────────────────────────────────────
 *
 * Everything here is arithmetic over plain objects — no Firestore, no
 * SDK — so the caps, the radius rule and the owner exclusion can be
 * asserted directly. These are exactly the one-line rules that vanish
 * in a later refactor: a missing `!== ownerId` turns the digest into
 * spam for the person who wrote the listing, and a missing cap turns
 * it back into the thing it replaced.
 */

/** The three kinds of listing a digest can mention. */
export type IntentType = "offer" | "pinbox" | "event";

export const INTENT_TYPES: readonly IntentType[] = ["offer", "pinbox", "event"];

/** One listing published today, as recorded by its own trigger. */
export interface DigestIntent {
  type: IntentType;
  venueId: string;
  /** The venue owner — excluded from their own digest. */
  ownerId: string;
  lat: number;
  lng: number;
}

/** The recipient side: one candidate and the radius they chose. */
export interface DigestRecipient {
  uid: string;
  lat?: number;
  lng?: number;
  country?: string;
  /** `distance` | `country` | `world`, or absent for "unrestricted". */
  discoverRadiusMode?: string;
  discoverRadiusKm?: number;
}

/** How many notifications one user may receive from one digest run —
 * one per content type, and there are three types. Not a separate
 * knob: a fourth type would raise it, anything else is a bug. */
export const MAX_DIGEST_NOTIFICATIONS_PER_USER = INTENT_TYPES.length;

/**
 * How long an intent stays readable before Firestore's TTL removes it.
 *
 * THREE DAYS, and the reason is correctness rather than diagnostics.
 * The digest runs mid-afternoon and looks back a full 24 hours, so a
 * single run reads across two calendar days — yesterday's evening and
 * this morning. Two days is therefore the minimum that can be correct
 * at all; the third is slack for a run that failed or was paused, so a
 * missed day is recoverable instead of silently dropped.
 *
 * Nothing here sweeps: the intent carries `expiresAt` and a native TTL
 * policy on the collection removes it. That is deliberate — the
 * alternative, a scheduled `recursiveDelete`, would cost one read plus
 * one delete per intent per day, and would be one more cleanup job to
 * forget. `birthdayMatches` is the local example of what forgetting
 * looks like (docs/BACKLOG.md #26); the fix for that class of bug is a
 * structure that cannot accumulate, not another function that tidies.
 */
export const INTENT_RETENTION_DAYS = 3;

/** The window a single digest run considers "new". */
export const DIGEST_LOOKBACK_MS = 24 * 60 * 60 * 1000;

function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const earthRadiusMeters = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(a));
}

/**
 * Whether [intent] falls inside [recipient]'s own chosen reach.
 *
 * The recipient's radius is the ONLY geographic gate, matching
 * `isWithinRecipientDiscoverRadius` in index.ts: a venue cannot
 * broadcast its way into someone who narrowed their own Discover
 * radius. A missing mode means unrestricted rather than silently
 * excluded — the same policy as everywhere else, so a user who has
 * never opened Discover still hears about things.
 */
export function isIntentInReach(intent: DigestIntent, recipient: DigestRecipient, venueCountry?: string): boolean {
  const mode = recipient.discoverRadiusMode;
  if (mode === undefined || mode === "world") return true;
  if (mode === "country") return venueCountry !== undefined && venueCountry === recipient.country;
  if (typeof recipient.lat !== "number" || typeof recipient.lng !== "number") return false;
  const radiusKm = recipient.discoverRadiusKm;
  if (typeof radiusKm !== "number") return true;
  return haversineMeters(recipient.lat, recipient.lng, intent.lat, intent.lng) <= radiusKm * 1000;
}

/** What one user should be told, or an empty object for "nothing". */
export type DigestCounts = Partial<Record<IntentType, number>>;

/**
 * Counts, per type, what [recipient] should hear about.
 *
 * Excludes intents the recipient owns. A venue owner is also a user,
 * and telling them "3 new campaigns nearby" about campaigns they wrote
 * themselves is the kind of detail that makes a product feel
 * unattended.
 *
 * A type with zero matches is ABSENT from the result rather than
 * present as `0` — the caller sends one notification per present key,
 * so "no new PinBoxes" produces silence instead of "0 new PinBoxes".
 */
export function digestCountsFor(
  intents: readonly DigestIntent[],
  recipient: DigestRecipient,
  countryByVenueId: ReadonlyMap<string, string | undefined> = new Map(),
): DigestCounts {
  const counts: DigestCounts = {};
  for (const intent of intents) {
    if (intent.ownerId === recipient.uid) continue;
    if (!isIntentInReach(intent, recipient, countryByVenueId.get(intent.venueId))) continue;
    counts[intent.type] = (counts[intent.type] ?? 0) + 1;
  }
  return counts;
}

/**
 * The counts as an ordered list of notifications to send.
 *
 * Order is [INTENT_TYPES]' order, so a user who gets all three always
 * sees them in the same sequence rather than in whatever order a Map
 * happened to iterate.
 */
export function digestNotifications(counts: DigestCounts): { type: IntentType; count: number }[] {
  return INTENT_TYPES.filter((t) => (counts[t] ?? 0) > 0).map((t) => ({ type: t, count: counts[t]! }));
}
