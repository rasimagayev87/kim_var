import "server-only";

import { getAdminDb, getAdminStorage } from "@/lib/firebase/admin";

export type IdentityVerificationStatus = "pending" | "approved" | "rejected";

export interface AdminIdentityVerificationRow {
  id: string;
  userId: string;
  userName: string;
  userUsername: string | null;
  status: IdentityVerificationStatus;
  rejectionReason: string | null;
  submittedAt: string | null;
  reviewedAt: string | null;
}

/** [AdminIdentityVerificationRow] plus the three images, as short-lived
 * signed URLs generated fresh on every detail-page load — never
 * stored, never handed to the client as anything but this one-time
 * render. See storage.rules' `identity_verifications/` block: there's
 * no other way to view these, by design. */
export interface AdminIdentityVerificationDetail extends AdminIdentityVerificationRow {
  idFrontUrl: string;
  idBackUrl: string;
  selfieWithIdUrl: string;
}

const FETCH_LIMIT = 200;

/** 10 minutes — long enough for one admin to review a single request
 * without the images going stale mid-read, short enough that a leaked
 * link (screenshot of a URL, browser history, a proxy log) is useless
 * shortly after. Regenerated fresh on every page load, so there's no
 * reason for it to outlive one review session. */
const SIGNED_URL_TTL_MS = 10 * 60 * 1000;

export type IdentityVerificationStatusFilter = "all" | IdentityVerificationStatus;

export async function listIdentityVerifications(
  statusFilter: IdentityVerificationStatusFilter,
): Promise<AdminIdentityVerificationRow[]> {
  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("identityVerifications");
  if (statusFilter !== "all") {
    query = query.where("status", "==", statusFilter);
  }

  const snap = await query.orderBy("submittedAt", "desc").limit(FETCH_LIMIT).get();
  return attachUsers(snap.docs);
}

export async function getIdentityVerificationDetail(id: string): Promise<AdminIdentityVerificationDetail | null> {
  const doc = await getAdminDb().collection("identityVerifications").doc(id).get();
  if (!doc.exists) return null;
  const [row] = await attachUsers([doc as FirebaseFirestore.QueryDocumentSnapshot]);

  const data = doc.data()!;
  const bucket = getAdminStorage().bucket();
  const expires = Date.now() + SIGNED_URL_TTL_MS;
  const [idFrontUrl, idBackUrl, selfieWithIdUrl] = await Promise.all([
    bucket.file(data.idFrontPath as string).getSignedUrl({ action: "read", expires }),
    bucket.file(data.idBackPath as string).getSignedUrl({ action: "read", expires }),
    bucket.file(data.selfieWithIdPath as string).getSignedUrl({ action: "read", expires }),
  ]);

  return { ...row, idFrontUrl: idFrontUrl[0], idBackUrl: idBackUrl[0], selfieWithIdUrl: selfieWithIdUrl[0] };
}

async function attachUsers(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
): Promise<AdminIdentityVerificationRow[]> {
  const db = getAdminDb();
  const userIds = [...new Set(docs.map((doc) => doc.data().userId as string))];
  const userDocs = await Promise.all(userIds.map((uid) => db.collection("users").doc(uid).get()));
  const userByUid = new Map(userDocs.map((doc) => [doc.id, doc.data()]));

  return docs.map((doc) => {
    const data = doc.data();
    const user = userByUid.get(data.userId as string);
    const submittedAt = data.submittedAt as FirebaseFirestore.Timestamp | undefined;
    const reviewedAt = data.reviewedAt as FirebaseFirestore.Timestamp | undefined;

    return {
      id: doc.id,
      userId: data.userId as string,
      userName: user ? `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || "Naməlum" : "Naməlum",
      userUsername: (user?.username as string) ?? null,
      status: (data.status as IdentityVerificationStatus) ?? "pending",
      rejectionReason: (data.rejectionReason as string) ?? null,
      submittedAt: submittedAt ? submittedAt.toDate().toISOString() : null,
      reviewedAt: reviewedAt ? reviewedAt.toDate().toISOString() : null,
    };
  });
}
