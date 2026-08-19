import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import type { PendingCounts } from "@/lib/pending-sections";

export type { PendingCounts } from "@/lib/pending-sections";
export { PENDING_SECTION_META } from "@/lib/pending-sections";

/**
 * One shared source for "how many items are waiting on this admin" —
 * a single set of `count()` aggregation queries (server-side counts,
 * not fetch-and-count) fetched once per request in the protected
 * layout and passed down to both the Sidebar (per-section badges) and
 * the Bell (aggregate + per-section dropdown), so neither one issues
 * its own duplicate queries. No notification documents are stored —
 * these are live counts, recomputed on every navigation.
 *
 * `eventReports` is deliberately NOT `status == "pending"` — that
 * collection's own status enum is `"open" | "resolved" | "dismissed"`
 * (see `event-reports.ts`), so "open" is what "still needs review"
 * means there.
 *
 * The `PendingCounts` shape and `PENDING_SECTION_META` display labels
 * live in `@/lib/pending-sections` (no `"server-only"`) so client
 * components like `NotificationBell` can import them without pulling
 * the Admin SDK into the browser bundle; re-exported here so existing
 * server-side imports don't need to change.
 */
export async function getPendingCounts(): Promise<PendingCounts> {
  const db = getAdminDb();

  const [venuesSnap, offersSnap, identitySnap, reportsSnap, eventReportsSnap, paymentsSnap] = await Promise.all([
    db.collection("venues").where("status", "==", "pending").count().get(),
    db.collection("offers").where("status", "==", "pending").count().get(),
    db.collection("identityVerifications").where("status", "==", "pending").count().get(),
    db.collection("reports").where("status", "==", "pending").count().get(),
    db.collection("eventReports").where("status", "==", "open").count().get(),
    db.collection("payments").where("status", "==", "pending").count().get(),
  ]);

  return {
    venues: venuesSnap.data().count,
    offers: offersSnap.data().count,
    identityVerifications: identitySnap.data().count,
    reports: reportsSnap.data().count,
    eventReports: eventReportsSnap.data().count,
    payments: paymentsSnap.data().count,
  };
}
