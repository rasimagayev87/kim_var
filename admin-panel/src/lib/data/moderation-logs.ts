import "server-only";

import { getAdminDb } from "@/lib/firebase/admin";

export type ModerationAction =
  | "venue.approved"
  | "venue.rejected"
  | "venue.activated"
  | "venue.deactivated"
  | "offer.approved"
  | "offer.rejected"
  | "offer.activated"
  | "offer.deactivated"
  | "user.banned"
  | "user.unbanned"
  | "user.verified"
  | "user.unverified"
  | "user.vipGranted"
  | "user.vipRevoked"
  | "post.deleted"
  | "comment.deleted"
  | "report.statusChanged"
  | "broadcast.sent"
  | "admin.added"
  | "admin.roleChanged"
  | "admin.removed";

export type ModerationTargetType =
  | "user"
  | "venue"
  | "offer"
  | "post"
  | "comment"
  | "report"
  | "broadcast"
  | "admin";

export interface ModerationLogRow {
  id: string;
  actorUid: string;
  actorEmail: string;
  actorRole: "admin" | "moderator";
  action: ModerationAction;
  targetType: ModerationTargetType;
  targetId: string;
  /** Free-form extra context (e.g. a report's dismissal reason) — kept
   * as a single optional string rather than an open `Record<string,
   * unknown>` so the log stays human-readable in the UI without a
   * bespoke renderer per action type. */
  note?: string;
  createdAt: string;
}

const LOG_FETCH_LIMIT = 200;

export async function listModerationLogs(): Promise<ModerationLogRow[]> {
  const snap = await getAdminDb().collection("moderationLogs").orderBy("createdAt", "desc").limit(LOG_FETCH_LIMIT).get();

  return snap.docs.map((doc) => {
    const data = doc.data();
    const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
    return {
      id: doc.id,
      actorUid: data.actorUid as string,
      actorEmail: data.actorEmail as string,
      actorRole: data.actorRole as "admin" | "moderator",
      action: data.action as ModerationAction,
      targetType: data.targetType as ModerationTargetType,
      targetId: data.targetId as string,
      note: (data.note as string) || undefined,
      createdAt: createdAt ? createdAt.toDate().toISOString() : new Date(0).toISOString(),
    };
  });
}
