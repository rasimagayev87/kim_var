import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors `reviewReports/{reportId}.status` — the mobile app only
 * ever writes `pending` (see firestore.rules: client create-only,
 * everything else denied), `resolved`/`dismissed` are admin-set from
 * here. Named `pending` rather than `open` (unlike `eventReports`) to
 * match the pre-existing generic `reports` collection's own
 * convention — this app already has both spellings in the wild. */
export type ReviewReportStatus = "pending" | "resolved" | "dismissed";
export type ReviewReportStatusFilter = "all" | ReviewReportStatus;

export interface AdminReviewReportRow {
  id: string;
  reviewId: string;
  reviewComment: string;
  reviewRating: number | null;
  reviewDeleted: boolean;
  venueId: string;
  venueName: string;
  reporterId: string;
  reporterName: string;
  reason: string;
  status: ReviewReportStatus;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): ReviewReportStatus {
  return value === "resolved" || value === "dismissed" ? value : "pending";
}

export async function listReviewReports({ status }: { status: ReviewReportStatusFilter }): Promise<AdminReviewReportRow[]> {
  // Same bounded-fetch-then-filter-in-memory reasoning as
  // lib/data/event-reports.ts — no composite index for
  // status+timestamp, small enough today for one bounded fetch.
  const snap = await getAdminDb().collection("reviewReports").orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  const rows = await attachDetails(snap.docs);
  return status === "all" ? rows : rows.filter((row) => row.status === status);
}

async function attachDetails(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminReviewReportRow[]> {
  const db = getAdminDb();

  const reviewIds = new Set<string>();
  const venueIds = new Set<string>();
  const reporterIds = new Set<string>();
  for (const doc of docs) {
    reviewIds.add(doc.data().reviewId as string);
    venueIds.add(doc.data().venueId as string);
    reporterIds.add(doc.data().reporterId as string);
  }

  const [reviewDocs, venueDocs, reporterDocs] = await Promise.all([
    Promise.all([...reviewIds].map((id) => db.collection("reviews").doc(id).get())),
    Promise.all([...venueIds].map((id) => db.collection("venues").doc(id).get())),
    Promise.all([...reporterIds].map((uid) => db.collection("users").doc(uid).get())),
  ]);
  const reviewById = new Map(reviewDocs.map((doc) => [doc.id, doc]));
  const venueById = new Map(venueDocs.map((doc) => [doc.id, doc.data()]));
  const userByUid = new Map(reporterDocs.map((doc) => [doc.id, doc.data()]));

  function displayName(uid: string): string {
    const user = userByUid.get(uid);
    return user ? `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum";
  }

  return docs.map((doc) => {
    const data = doc.data();
    const reviewId = data.reviewId as string;
    const reviewDoc = reviewById.get(reviewId);
    const reviewData = reviewDoc?.data();
    const venueId = data.venueId as string;
    const timestamp = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      reviewId,
      reviewComment: (reviewData?.comment as string) ?? "",
      reviewRating: (reviewData?.rating as number) ?? null,
      reviewDeleted: !reviewDoc?.exists,
      venueId,
      venueName: (venueById.get(venueId)?.name as string) ?? "",
      reporterId: data.reporterId as string,
      reporterName: displayName(data.reporterId as string),
      reason: (data.reason as string) ?? "",
      status: parseStatus(data.status),
      createdAt: timestamp ? timestamp.toDate().toISOString() : null,
    };
  });
}
