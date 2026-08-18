import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export interface AdminNotificationRow {
  id: string;
  type: string;
  message: string;
  targetType: string;
  targetId: string;
  read: boolean;
  createdAt: string | null;
}

const FETCH_LIMIT = 20;

/** Backs the Topbar's Bell dropdown — most recent first, capped at
 * [FETCH_LIMIT] (this is a glance-at-recent-activity list, not a full
 * archive/pagination view). */
export async function listRecentAdminNotifications(): Promise<AdminNotificationRow[]> {
  const snap = await getAdminDb().collection("adminNotifications").orderBy("createdAt", "desc").limit(FETCH_LIMIT).get();
  return snap.docs.map(docToRow);
}

export async function getUnreadAdminNotificationsCount(): Promise<number> {
  const snap = await getAdminDb().collection("adminNotifications").where("read", "==", false).count().get();
  return snap.data().count;
}

function docToRow(doc: FirebaseFirestore.QueryDocumentSnapshot): AdminNotificationRow {
  const data = doc.data();
  const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
  return {
    id: doc.id,
    type: (data.type as string) ?? "",
    message: (data.message as string) ?? "",
    targetType: (data.targetType as string) ?? "",
    targetId: (data.targetId as string) ?? "",
    read: (data.read as boolean) ?? false,
    createdAt: createdAt ? createdAt.toDate().toISOString() : null,
  };
}
