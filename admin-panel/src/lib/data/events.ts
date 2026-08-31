import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";
import { eventUrgency } from "@/lib/event-urgency";

/**
 * The events moderation queue's data layer.
 *
 * Events had NO admin surface at all before this — only
 * `/event-reports`, which meant a moderator could see an event solely
 * if somebody complained about one. They were simultaneously the only
 * listing that reached a push notification (the daily digest) with no
 * review and no payment behind it.
 *
 * The fix is trust-based rather than blanket: a venue's first
 * `EVENT_TRUST_THRESHOLD` events are `pending` and land here;
 * everything after publishes on creation. See `onVenueEventCreated`.
 */
export type EventStatus = "pending" | "upcoming" | "live" | "ended" | "cancelled" | "rejected";
export type EventStatusFilter = "all" | EventStatus;

export interface AdminEventRow {
  id: string;
  title: string;
  description: string;
  coverImageUrl: string | null;
  venueId: string;
  venueName: string;
  venuePhotoUrl: string | null;
  category: string;
  venueCategory: string;
  status: EventStatus;
  reviewNote: string | null;
  startAt: string | null;
  endAt: string | null;
  createdAt: string | null;
  /** How many events this venue has already published — the number the
   * trust threshold is measured against, shown so a moderator can see
   * whether this is a venue's first event or its third. */
  venuePublishedEventCount: number;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): EventStatus {
  return value === "upcoming" || value === "live" || value === "ended" ||
    value === "cancelled" || value === "rejected"
    ? value
    : "pending";
}

function toIso(value: unknown): string | null {
  const ts = value as FirebaseFirestore.Timestamp | undefined;
  return ts ? ts.toDate().toISOString() : null;
}

export function parseEventStatusFilter(value: unknown): EventStatusFilter {
  return value === "all" || value === "upcoming" || value === "live" || value === "ended" ||
    value === "cancelled" || value === "rejected"
    ? value
    : "pending";
}

export async function listEvents({
  status,
  search,
  venueId,
}: {
  status: EventStatusFilter;
  search: string;
  venueId?: string;
}): Promise<AdminEventRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("venueEvents");
  if (status !== "all") query = query.where("status", "==", status);
  if (venueId) query = query.where("venueId", "==", venueId);

  const snap = await query.orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  let rows = await attachVenues(snap.docs);

  const key = search.trim().toLowerCase();
  if (key) {
    rows = rows.filter(
      (row) => row.title.toLowerCase().includes(key) || row.venueName.toLowerCase().includes(key),
    );
  }

  // Soonest first among the pending ones, and pending before anything
  // else. An event is the only listing with a deadline the product
  // cannot move: past its own `startAt` it is auto-rejected, because
  // publishing something that has already begun is worse than not
  // publishing it. `createdAt desc` would bury the one starting in an
  // hour under five created more recently for next month.
  const now = Date.now();
  return rows.sort((a, b) => {
    const aUrgent = eventUrgency(a.status, a.startAt ? Date.parse(a.startAt) : null, now);
    const bUrgent = eventUrgency(b.status, b.startAt ? Date.parse(b.startAt) : null, now);
    const rank = (k: string) => (k === "urgent" ? 0 : k === "upcoming" ? 1 : k === "missed" ? 2 : 3);
    if (rank(aUrgent.kind) !== rank(bUrgent.kind)) return rank(aUrgent.kind) - rank(bUrgent.kind);
    const aStart = a.startAt ? Date.parse(a.startAt) : Number.MAX_SAFE_INTEGER;
    const bStart = b.startAt ? Date.parse(b.startAt) : Number.MAX_SAFE_INTEGER;
    return aStart - bStart;
  });
}

export async function getEventDetail(id: string): Promise<AdminEventRow | null> {
  const doc = await getAdminDb().collection("venueEvents").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachVenues([doc as FirebaseFirestore.QueryDocumentSnapshot]);
  return row;
}

export async function countPendingEvents(): Promise<number> {
  const snap = await getAdminDb().collection("venueEvents").where("status", "==", "pending").count().get();
  return snap.data().count;
}

async function attachVenues(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminEventRow[]> {
  const db = getAdminDb();
  const venueIds = [...new Set(docs.map((doc) => doc.data().venueId as string).filter(Boolean))];
  const venueDocs = await Promise.all(venueIds.map((id) => db.collection("venues").doc(id).get()));
  const venueById = new Map(venueDocs.map((doc) => [doc.id, doc.data()]));

  return docs.map((doc) => {
    const data = doc.data();
    const venue = venueById.get(data.venueId as string);
    return {
      id: doc.id,
      title: (data.title as string) ?? "",
      description: (data.description as string) ?? "",
      coverImageUrl: (data.coverImageUrl as string) ?? null,
      venueId: (data.venueId as string) ?? "",
      venueName: (data.venueName as string) || (venue?.name as string) || "",
      venuePhotoUrl: (data.venuePhotoUrl as string) ?? (venue?.photoUrl as string) ?? null,
      category: (data.category as string) ?? "other",
      venueCategory: (data.venueCategory as string) ?? (venue?.category as string) ?? "other",
      status: parseStatus(data.status),
      reviewNote: (data.reviewNote as string) || null,
      startAt: toIso(data.startAt),
      endAt: toIso(data.endAt),
      createdAt: toIso(data.createdAt),
      venuePublishedEventCount: (venue?.publishedEventCount as number | undefined) ?? 0,
    };
  });
}
