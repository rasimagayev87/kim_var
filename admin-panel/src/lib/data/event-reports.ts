import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors `eventReports/{reportId}.status` — the mobile app only ever
 * writes `open` (see firestore.rules: client create-only, everything
 * else denied), `resolved`/`dismissed` are admin-set from here. */
export type EventReportStatus = "open" | "resolved" | "dismissed";
export type EventReportStatusFilter = "all" | EventReportStatus;

export interface AdminEventReportRow {
  id: string;
  eventId: string;
  eventTitle: string;
  eventStatus: string;
  venueId: string | null;
  venueName: string;
  reportedBy: string;
  reporterName: string;
  reason: string;
  status: EventReportStatus;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): EventReportStatus {
  return value === "resolved" || value === "dismissed" ? value : "open";
}

export async function listEventReports({ status }: { status: EventReportStatusFilter }): Promise<AdminEventReportRow[]> {
  // Same bounded-fetch-then-filter-in-memory reasoning as
  // lib/data/reports.ts — this collection has no existing composite
  // index for status+timestamp, and is small enough today that one
  // bounded fetch is fine.
  const snap = await getAdminDb().collection("eventReports").orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  const rows = await attachDetails(snap.docs);
  return status === "all" ? rows : rows.filter((row) => row.status === status);
}

async function attachDetails(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminEventReportRow[]> {
  const db = getAdminDb();

  const eventIds = new Set<string>();
  const reporterIds = new Set<string>();
  for (const doc of docs) {
    eventIds.add(doc.data().eventId as string);
    reporterIds.add(doc.data().reportedBy as string);
  }

  const [eventDocs, reporterDocs] = await Promise.all([
    Promise.all([...eventIds].map((id) => db.collection("venueEvents").doc(id).get())),
    Promise.all([...reporterIds].map((uid) => db.collection("users").doc(uid).get())),
  ]);
  const eventById = new Map(eventDocs.map((doc) => [doc.id, doc.data()]));
  const userByUid = new Map(reporterDocs.map((doc) => [doc.id, doc.data()]));

  function reporterName(uid: string): string {
    const user = userByUid.get(uid);
    return user ? `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum";
  }

  return docs.map((doc) => {
    const data = doc.data();
    const event = eventById.get(data.eventId as string);
    const timestamp = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      eventId: data.eventId as string,
      eventTitle: (event?.title as string) ?? "Silinmiş tədbir",
      eventStatus: (event?.status as string) ?? "unknown",
      venueId: (event?.venueId as string) ?? null,
      venueName: (event?.venueName as string) ?? "",
      reportedBy: data.reportedBy as string,
      reporterName: reporterName(data.reportedBy as string),
      reason: (data.reason as string) ?? "",
      status: parseStatus(data.status),
      createdAt: timestamp ? timestamp.toDate().toISOString() : null,
    };
  });
}
