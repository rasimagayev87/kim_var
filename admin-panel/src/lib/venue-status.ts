/**
 * Venue status vocabulary, free of any import.
 *
 * Separate from `lib/data/venues.ts` for the same reason `auth/roles.ts`
 * is separate from `auth/session.ts`: that module carries
 * `import "server-only"`, which makes it unimportable from a Client
 * Component — and from a test. The statuses themselves are just
 * strings and belong somewhere both sides can reach.
 */

/**
 * Every status a venue document can HOLD.
 *
 * `subscription_overdue` is written by `renewVenueSubscriptions`
 * (functions/src/index.ts) when a monthly charge goes unpaid past the
 * grace period; such a venue is not discoverable in the app. It was
 * missing from this union while `parseStatus` defaulted to
 * `"approved"`, so `/venues` showed a suspended venue as active — the
 * worst direction for a wrong default to point.
 */
export type VenueStatus =
  | "approved"
  | "pending"
  | "needs_revision"
  | "rejected"
  | "inactive"
  | "awaiting_payment"
  | "subscription_overdue";

export const VENUE_STATUSES: readonly VenueStatus[] = [
  "approved", "pending", "needs_revision", "rejected", "inactive",
  "awaiting_payment", "subscription_overdue",
];

/**
 * The subset a moderator may WRITE through `setVenueStatus`.
 *
 * Deliberately narrower than [VenueStatus]. `subscription_overdue` and
 * `awaiting_payment` are billing states owned by the payment flow;
 * letting the moderation UI set them by hand would mean an admin could
 * mark a venue delinquent — or clear a genuine delinquency — with no
 * payment record either way. Widening the display union must not
 * silently widen what the action accepts, which is exactly what would
 * have happened had these stayed one type.
 */
export type VenueModerationStatus = Extract<
  VenueStatus,
  "approved" | "pending" | "needs_revision" | "rejected" | "inactive"
>;

export const VENUE_MODERATION_STATUSES: readonly VenueModerationStatus[] = [
  "approved", "pending", "needs_revision", "rejected", "inactive",
];

export type VenueStatusFilter = "all" | VenueStatus;

export function isVenueStatus(value: unknown): value is VenueStatus {
  return typeof value === "string" && (VENUE_STATUSES as readonly string[]).includes(value);
}

export function isVenueModerationStatus(value: unknown): value is VenueModerationStatus {
  return typeof value === "string" && (VENUE_MODERATION_STATUSES as readonly string[]).includes(value);
}
