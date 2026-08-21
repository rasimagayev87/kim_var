import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export interface DashboardStats {
  totalUsers: number;
  activeVenues: number;
  activeOffers: number;
  activeEvents: number;
  activePinBoxes: number;
  pendingModeration: number;
  pendingReports: number;
}

export interface RegistrationDay {
  /** ISO date (yyyy-mm-dd), local server time. */
  date: string;
  count: number;
}

/**
 * Top-line counters for the dashboard's stat cards — every count uses
 * Firestore's `count()` aggregation query (a single server-side
 * aggregate, not "fetch every doc and count them client-side"), so
 * this stays cheap even once `users`/`venues`/`offers` have tens of
 * thousands of docs.
 */
export async function getDashboardStats(): Promise<DashboardStats> {
  const db = getAdminDb();

  const [
    usersSnap,
    activeVenuesSnap,
    activeOffersSnap,
    activeEventsSnap,
    activePinBoxesSnap,
    pendingVenuesSnap,
    pendingOffersSnap,
    pendingReportsSnap,
    pendingIdentityVerificationsSnap,
  ] = await Promise.all([
    db.collection("users").count().get(),
    db.collection("venues").where("status", "==", "approved").count().get(),
    db.collection("offers").where("status", "==", "approved").count().get(),
    // "upcoming"/"live" (see advanceVenueEventStatuses, functions/src/
    // index.ts) — an event auto-cancelled or past "ended" isn't active
    // anymore, mirrors why the venue/offer counts above filter on
    // their own "currently visible" status rather than every doc ever
    // created.
    db.collection("venueEvents").where("status", "in", ["upcoming", "live"]).count().get(),
    db.collection("pinboxes").where("status", "==", "active").count().get(),
    db.collection("venues").where("status", "==", "pending").count().get(),
    db.collection("offers").where("status", "==", "pending").count().get(),
    db.collection("reports").where("status", "==", "pending").count().get(),
    db.collection("identityVerifications").where("status", "==", "pending").count().get(),
  ]);

  return {
    totalUsers: usersSnap.data().count,
    activeVenues: activeVenuesSnap.data().count,
    activeOffers: activeOffersSnap.data().count,
    activeEvents: activeEventsSnap.data().count,
    activePinBoxes: activePinBoxesSnap.data().count,
    pendingModeration:
      pendingVenuesSnap.data().count + pendingOffersSnap.data().count + pendingIdentityVerificationsSnap.data().count,
    pendingReports: pendingReportsSnap.data().count,
  };
}

/**
 * Backs the Dashboard's "Online İstifadəçilər" KPI. `online` is written
 * by the Flutter app itself (LocationController), the same field the
 * `users` collection's `country`+`online` composite index already
 * exists for — this is a new aggregate read on an existing field, not
 * a new Firestore field/write path.
 */
export async function getOnlineUsersCount(): Promise<number> {
  const db = getAdminDb();
  const snap = await db.collection("users").where("online", "==", true).count().get();
  return snap.data().count;
}

/**
 * New-account count per day for the last 7 days (today inclusive),
 * oldest first — backs the dashboard's registration chart.
 *
 * Firestore has no server-side `GROUP BY`, so this fetches just the
 * `createdAt` field (via `.select`, not full documents) for accounts
 * created in the window and buckets them in memory — fine at today's
 * scale (a week of signups), worth revisiting with a scheduled
 * roll-up doc if daily signups ever get large enough for this read to
 * matter.
 */
export async function getRegistrationsLast7Days(): Promise<RegistrationDay[]> {
  const db = getAdminDb();

  const days: RegistrationDay[] = [];
  const dayStarts: Date[] = [];
  const now = new Date();
  for (let i = 6; i >= 0; i--) {
    const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
    dayStarts.push(dayStart);
    days.push({ date: dayStart.toISOString().slice(0, 10), count: 0 });
  }

  const windowStart = dayStarts[0];
  const snap = await db
    .collection("users")
    .where("createdAt", ">=", windowStart)
    .select("createdAt")
    .get();

  const countByIndex = new Map<number, number>();
  for (const doc of snap.docs) {
    const createdAt = doc.get("createdAt")?.toDate?.() as Date | undefined;
    if (!createdAt) continue;
    const dayIndex = dayStarts.findIndex((start, i) => {
      const next = i + 1 < dayStarts.length ? dayStarts[i + 1] : undefined;
      return createdAt >= start && (!next || createdAt < next);
    });
    if (dayIndex === -1) continue;
    countByIndex.set(dayIndex, (countByIndex.get(dayIndex) ?? 0) + 1);
  }

  for (const [index, count] of countByIndex) {
    days[index].count = count;
  }

  return days;
}
