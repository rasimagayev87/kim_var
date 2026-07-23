"use server";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
  sentCount?: number;
}

export type BroadcastSegment = "all" | "vip" | "verified";
export type BroadcastType = "announcement" | "promotion";

async function requireBroadcastPermission(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "broadcastNotifications")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** Resolves a segment to the exact uid list it targets — kept separate
 * from `sendBroadcast` so the UI can show a live "N istifadəçiyə
 * göndəriləcək" count before the admin actually commits to sending. */
export async function countBroadcastAudience(segment: BroadcastSegment): Promise<number | { error: string }> {
  const check = await requireBroadcastPermission();
  if ("denied" in check) return { error: check.denied.error ?? "forbidden" };

  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("users");
  if (segment === "vip") query = query.where("premium", "==", true);
  if (segment === "verified") query = query.where("isVerified", "==", true);

  const snap = await query.count().get();
  return snap.data().count;
}

/**
 * Writes one `users/{uid}/notifications` doc per targeted user via
 * `BulkWriter` — unlike a plain `WriteBatch` (hard-capped at 500
 * operations, all-or-nothing), BulkWriter has no size limit and
 * retries individual failed writes on its own, which is what makes
 * this safe to point at a segment of any size. Field shape mirrors
 * exactly what `FirebaseNotificationRepository`/`AppNotification` on
 * the mobile side read (see notification.dart) — no sender fields,
 * since this is system-authored, not from another user.
 */
export async function sendBroadcast({
  title,
  body,
  type,
  segment,
}: {
  title: string;
  body: string;
  type: BroadcastType;
  segment: BroadcastSegment;
}): Promise<ActionResult> {
  const check = await requireBroadcastPermission();
  if ("denied" in check) return check.denied;

  const trimmedTitle = title.trim();
  const trimmedBody = body.trim();
  if (!trimmedTitle || !trimmedBody) {
    return { ok: false, error: "invalid-input" };
  }

  try {
    const db = getAdminDb();
    let query: FirebaseFirestore.Query = db.collection("users");
    if (segment === "vip") query = query.where("premium", "==", true);
    if (segment === "verified") query = query.where("isVerified", "==", true);

    const snap = await query.select().get();
    if (snap.empty) {
      return { ok: false, error: "empty-audience" };
    }

    const writer = db.bulkWriter();
    let failureCount = 0;
    writer.onWriteError((error) => {
      failureCount += 1;
      // BulkWriter retries transient errors on its own; returning
      // false here means "don't retry further" for errors it judged
      // non-transient — logged via the counter, not thrown, so one bad
      // doc doesn't abort the whole broadcast.
      return error.failedAttempts < 3;
    });

    for (const doc of snap.docs) {
      const notificationRef = doc.ref.collection("notifications").doc();
      writer.create(notificationRef, {
        type,
        title: trimmedTitle,
        body: trimmedBody,
        isRead: false,
        createdAt: new Date(),
      });
    }

    await writer.close();

    const sentCount = snap.size - failureCount;

    await logModerationAction({
      actor: check.admin,
      action: "broadcast.sent",
      targetType: "broadcast",
      targetId: segment,
      note: `"${trimmedTitle}" → ${sentCount}/${snap.size} istifadəçi`,
    });

    return { ok: true, sentCount };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
