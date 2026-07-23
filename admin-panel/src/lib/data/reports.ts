import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

/** Mirrors the values `FirebaseSafetyRepository.reportUser` and a
 * moderator's own status changes can put on a `reports` doc — the
 * mobile app only ever writes `pending` (see firestore.rules' `reports`
 * block: client create-only, everything else denied), the other three
 * are moderator-set from here. */
export type ReportStatus = "pending" | "reviewed" | "actioned" | "dismissed";
export type ReportStatusFilter = "all" | ReportStatus;

export interface AdminReportRow {
  id: string;
  reporterId: string;
  reporterName: string;
  reportedUserId: string;
  reportedUserName: string;
  reason: string;
  chatId: string | null;
  status: ReportStatus;
  createdAt: string | null;
}

const FETCH_LIMIT = 200;

function parseStatus(value: unknown): ReportStatus {
  return value === "reviewed" || value === "actioned" || value === "dismissed" ? value : "pending";
}

export async function listReports({ status }: { status: ReportStatusFilter }): Promise<AdminReportRow[]> {
  // Filtered in-memory rather than a Firestore `where` — `reports` has
  // no existing composite index for status+timestamp (the mobile app
  // never queries this collection at all, only writes to it), and this
  // collection is small enough at today's scale that one bounded fetch
  // is fine. Same reasoning as the other bounded-fetch data layers in
  // this admin panel (see lib/data/users.ts).
  const snap = await getAdminDb().collection("reports").orderBy("timestamp", "desc").limit(FETCH_LIMIT).get();
  const rows = await attachUsers(snap.docs);
  return status === "all" ? rows : rows.filter((row) => row.status === status);
}

export async function getReportDetail(id: string): Promise<AdminReportRow | null> {
  const doc = await getAdminDb().collection("reports").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachUsers([doc as FirebaseFirestore.QueryDocumentSnapshot]);
  return row;
}

async function attachUsers(docs: FirebaseFirestore.QueryDocumentSnapshot[]): Promise<AdminReportRow[]> {
  const db = getAdminDb();
  const uids = new Set<string>();
  for (const doc of docs) {
    uids.add(doc.data().reporterId as string);
    uids.add(doc.data().reportedUserId as string);
  }
  const userDocs = await Promise.all([...uids].map((uid) => db.collection("users").doc(uid).get()));
  const userByUid = new Map(userDocs.map((doc) => [doc.id, doc.data()]));

  function nameFor(uid: string): string {
    const user = userByUid.get(uid);
    return user ? `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum";
  }

  return docs.map((doc) => {
    const data = doc.data();
    const timestamp = data.timestamp as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      reporterId: data.reporterId as string,
      reporterName: nameFor(data.reporterId as string),
      reportedUserId: data.reportedUserId as string,
      reportedUserName: nameFor(data.reportedUserId as string),
      reason: (data.reason as string) ?? "",
      chatId: (data.chatId as string) ?? null,
      status: parseStatus(data.status),
      createdAt: timestamp ? timestamp.toDate().toISOString() : null,
    };
  });
}
