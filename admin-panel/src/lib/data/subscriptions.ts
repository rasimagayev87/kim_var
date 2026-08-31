import "server-only";

import { Timestamp } from "firebase-admin/firestore";

import { getAdminDb } from "@/lib/firebase/admin";
import { venueSubscriptionFeeByCategory } from "@/lib/venue-fees";

/**
 * Read-only view of venue subscriptions for `/subscriptions`.
 *
 * NOTE ON STATUS. `subscription_overdue` is a real venue status —
 * `renewVenueSubscriptions` (functions/src/index.ts) sets it when a
 * venue's monthly charge goes unpaid past the grace period, and a
 * venue in that state is not discoverable. It is NOT in
 * `lib/data/venues.ts`' `VenueStatus` union, whose `parseStatus`
 * coerces anything unrecognised to `"approved"` — so an overdue venue
 * currently reads as approved on the venues screen. That is a separate
 * pre-existing bug (same shape as the admin-roster one: a stale
 * allowlist collapsing to a flattering default); this module does not
 * share that union precisely so it cannot inherit the coercion.
 */
export const SUBSCRIPTION_STATUSES = [
  "approved",
  "subscription_overdue",
  "awaiting_payment",
] as const;

export type SubscriptionStatus = (typeof SUBSCRIPTION_STATUSES)[number];
export type SubscriptionStatusFilter = "all" | SubscriptionStatus;

export function isSubscriptionStatus(value: unknown): value is SubscriptionStatus {
  return typeof value === "string" && (SUBSCRIPTION_STATUSES as readonly string[]).includes(value);
}

export interface SubscriptionRow {
  venueId: string;
  venueName: string;
  category: string;
  status: SubscriptionStatus | null;
  renewsAt: string | null;
  /**
   * Monthly price in AZN, or `null` when the category has no tier.
   *
   * OMITTED ENTIRELY for roles without `viewRevenue` — the field is
   * absent from the object, not blanked in the UI. See
   * [listSubscriptions].
   */
  monthlyFeeAzn?: number | null;
  /**
   * When the last completed `venue_subscription` payment for this venue
   * landed. Read from `payments`, never inferred: `renewsAt` minus a
   * cycle would look like a date and be a guess.
   *
   * Same `viewRevenue` treatment as [monthlyFeeAzn].
   */
  lastPaidAt?: string | null;
}

const FETCH_LIMIT = 200;

function isoOrNull(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

/**
 * @param includeMoney whether the caller holds `viewRevenue`. When
 * false, the fee and last-payment fields are not attached AND the
 * `payments` query is never run — a role that may not see money does
 * not cause a read of the money collection. Same reasoning as the
 * dashboard's conditional revenue fetch (P0 / H-7): hiding a column
 * client-side is not a boundary.
 *
 * COST: one venues query (≤200 docs) and, only for money-holding
 * roles, one payments query (≤200 docs). Both capped, neither scales
 * with total collection size.
 */
export async function listSubscriptions({
  status = "all",
  includeMoney,
}: {
  status?: SubscriptionStatusFilter;
  includeMoney: boolean;
}): Promise<SubscriptionRow[]> {
  const db = getAdminDb();

  let query: FirebaseFirestore.Query = db.collection("venues");
  query = isSubscriptionStatus(status)
    ? query.where("status", "==", status)
    : query.where("status", "in", [...SUBSCRIPTION_STATUSES]);

  const snap = await query.orderBy("subscriptionRenewsAt", "asc").limit(FETCH_LIMIT).get();

  const rows: SubscriptionRow[] = snap.docs.map((doc) => {
    const data = doc.data();
    const category = (data.category as string) ?? "";
    const row: SubscriptionRow = {
      venueId: doc.id,
      venueName: (data.name as string) ?? "",
      category,
      status: isSubscriptionStatus(data.status) ? data.status : null,
      renewsAt: isoOrNull(data.subscriptionRenewsAt),
    };
    if (includeMoney) {
      row.monthlyFeeAzn = venueSubscriptionFeeByCategory[category] ?? null;
      row.lastPaidAt = null; // filled below
    }
    return row;
  });

  if (!includeMoney || rows.length === 0) return rows;

  // One query for the whole page rather than one per venue. Uses the
  // existing `payments (status, type, createdAt)` index.
  //
  // Caught rather than awaited bare: this is a SECONDARY column on a
  // page whose primary content is already loaded. If the index is
  // missing or rebuilding, the right outcome is a dash in the
  // "last paid" cell, not a 500 that hides the subscription list too.
  // `/analytics` learned this the hard way, and `pending-counts.ts`
  // before it.
  let paymentsSnap: FirebaseFirestore.QuerySnapshot | null = null;
  try {
    paymentsSnap = await db
      .collection("payments")
      .where("status", "==", "completed")
      .where("type", "==", "venue_subscription")
      .orderBy("createdAt", "desc")
      .limit(FETCH_LIMIT)
      .get();
  } catch (error) {
    console.error("listSubscriptions: last-payment lookup failed (missing/building index?)", error);
    return rows; // `lastPaidAt` stays null; every other column is intact.
  }

  const latestByVenue = new Map<string, string>();
  for (const doc of paymentsSnap.docs) {
    const venueId = doc.get("listingId") as string | undefined;
    const at = isoOrNull(doc.get("createdAt"));
    // Ordered newest-first, so the first hit per venue is the latest.
    if (venueId && at && !latestByVenue.has(venueId)) latestByVenue.set(venueId, at);
  }
  for (const row of rows) {
    row.lastPaidAt = latestByVenue.get(row.venueId) ?? null;
  }
  return rows;
}
