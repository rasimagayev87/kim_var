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
 * `payments` is deliberately `status == "refund_pending"`, NOT
 * `"pending"` — every checkout starts life as `"pending"` for the few
 * seconds/minutes until Epoint's webhook resolves it, so that status
 * is a normal transient state, not a queue needing admin action (an
 * abandoned checkout just sits there forever with no admin workflow to
 * clear it). `refund_pending` is what the Payments page's own default
 * view and its "Geri qaytarıldı kimi işarələ" button actually act on —
 * this badge has to match that or it never reflects what the admin
 * just resolved.
 *
 * `premiumPayments` is a different kind of badge entirely — a
 * successful "Məkanı premium et" payment needs NO admin action (unlike
 * every other count here, which really is a queue), so there's no
 * status to filter on. It counts `venue_premium` payments completed in
 * the last 24 hours instead — a "what's new" indicator, not a
 * to-do-list count. Resets to 0 on its own as those payments age past
 * 24 hours, with nothing for an admin to "clear."
 *
 * The `PendingCounts` shape and `PENDING_SECTION_META` display labels
 * live in `@/lib/pending-sections` (no `"server-only"`) so client
 * components like `NotificationBell` can import them without pulling
 * the Admin SDK into the browser bundle; re-exported here so existing
 * server-side imports don't need to change.
 */
export async function getPendingCounts(): Promise<PendingCounts> {
  const db = getAdminDb();
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [
    venuesSnap,
    offersSnap,
    pinboxesSnap,
    identitySnap,
    reportsSnap,
    eventReportsSnap,
    reviewReportsSnap,
    paymentsSnap,
    pinboxPayoutsSnap,
    premiumPaymentsCount,
  ] = await Promise.all([
    db.collection("venues").where("status", "==", "pending").count().get(),
    db.collection("offers").where("status", "==", "pending").count().get(),
    db.collection("pinboxes").where("status", "==", "pending").count().get(),
    db.collection("identityVerifications").where("status", "==", "pending").count().get(),
    db.collection("reports").where("status", "==", "pending").count().get(),
    db.collection("eventReports").where("status", "==", "open").count().get(),
    db.collection("reviewReports").where("status", "==", "pending").count().get(),
    db.collection("payments").where("status", "==", "refund_pending").count().get(),
    db.collection("venuePayouts").where("status", "==", "pending").count().get(),
    // This 3-field query (type + status + createdAt range) needs its
    // own Firestore composite index, unlike every other query above
    // (each a single equality filter). Caught separately so a missing
    // or still-building index degrades to "0" instead of a rejected
    // Promise.all taking down every protected page's layout — this ran
    // production down once already before this try/catch existed.
    db
      .collection("payments")
      .where("type", "==", "venue_premium")
      .where("status", "==", "completed")
      .where("createdAt", ">=", oneDayAgo)
      .count()
      .get()
      .then((snap) => snap.data().count)
      .catch((error) => {
        console.error("getPendingCounts: premiumPayments query failed (missing/building index?)", error);
        return 0;
      }),
  ]);

  return {
    venues: venuesSnap.data().count,
    offers: offersSnap.data().count,
    pinboxes: pinboxesSnap.data().count,
    identityVerifications: identitySnap.data().count,
    reports: reportsSnap.data().count,
    eventReports: eventReportsSnap.data().count,
    reviewReports: reviewReportsSnap.data().count,
    payments: paymentsSnap.data().count,
    pinboxPayouts: pinboxPayoutsSnap.data().count,
    premiumPayments: premiumPaymentsCount,
  };
}
