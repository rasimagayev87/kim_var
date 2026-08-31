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
export type BroadcastType = "announcement" | "promotion" | "system";

/** Mirrors `notifyUser`'s own `prefs[category] === false` gate in
 * functions/src/index.ts — a broadcast is admin-authored, not
 * per-recipient, so there's no single Cloud Function call site to
 * inherit that gate from; `sendBroadcast` re-implements it here
 * instead of silently ignoring `NotificationPreferences.marketing`/
 * `systemNotifications` (both real, user-facing toggles in Settings —
 * see `notification_preferences.dart`), which would otherwise be dead
 * switches for every broadcast specifically. */
const PREFERENCE_KEY_BY_TYPE: Record<BroadcastType, string> = {
  promotion: "marketing",
  announcement: "systemNotifications",
  system: "systemNotifications",
};

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
export async function countBroadcastAudience(
  segment: BroadcastSegment,
  type: BroadcastType,
): Promise<number | { error: string }> {
  const check = await requireBroadcastPermission();
  if ("denied" in check) return { error: check.denied.error ?? "forbidden" };

  const db = getAdminDb();
  let query: FirebaseFirestore.Query = db.collection("users");
  if (segment === "vip") query = query.where("premium", "==", true);
  if (segment === "verified") query = query.where("identityVerified", "==", true);

  // Counts what will ACTUALLY be sent, not the raw segment size.
  //
  // This used to be a bare `.count()`, so the admin saw "500
  // istifadəçiyə göndəriləcək" and the send reported a smaller number
  // with no explanation. For `promotion` the gap is now the whole
  // audience — opt-in means almost nobody until users turn the switch
  // on — and a preview that hides that would read as a bug in the
  // send, not as the consent rule working.
  //
  // Costs one `private/data` read per candidate, same as `sendBroadcast`
  // itself. Acceptable: this runs when an admin opens the compose
  // screen, not per request.
  const snap = await query.select().get();
  if (snap.empty) return 0;

  const prefKey = PREFERENCE_KEY_BY_TYPE[type];
  const optInOnly = prefKey === "marketing";
  const privateSnaps = await Promise.all(
    snap.docs.map((doc) => doc.ref.collection("private").doc("data").get()),
  );
  return privateSnaps.filter((s) => {
    const value = s.data()?.notificationPreferences?.[prefKey];
    return optInOnly ? value === true : value !== false;
  }).length;
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
    if (segment === "verified") query = query.where("identityVerified", "==", true);

    // `notificationPreferences` moved to `users/{uid}/private/data`
    // (Düzəliş Prompt 4) — no longer selectable off the main `users`
    // query, so this needs one extra parallel read per candidate.
    const snap = await query.select().get();
    if (snap.empty) {
      return { ok: false, error: "empty-audience" };
    }

    const prefKey = PREFERENCE_KEY_BY_TYPE[type];
    const privateSnaps = await Promise.all(
      snap.docs.map((doc) => doc.ref.collection("private").doc("data").get()),
    );
    // OPT-IN for `marketing`, opt-OUT for everything else.
    //
    // `!== false` for every key was wrong for promotions specifically.
    // `updatePreferences` (the Flutter repository) writes only the keys
    // a user has actually toggled, so `marketing` is ABSENT from
    // Firestore for everyone who never opened the switch — and absent
    // read as consent. The client meanwhile defaulted it to `false` and
    // showed the switch off. Every user was being shown "promotions
    // off" while the server counted them as opted in.
    //
    // Promotional messaging is the one category where silence must not
    // mean yes: several jurisdictions require prior consent, and the
    // product decision is the same regardless. `=== true` demands the
    // stored flag, so a user reaches this audience only by turning the
    // switch on themselves.
    const optInOnly = prefKey === "marketing";
    const targetDocs = snap.docs.filter((_doc, i) => {
      const value = privateSnaps[i].data()?.notificationPreferences?.[prefKey];
      return optInOnly ? value === true : value !== false;
    });
    if (targetDocs.length === 0) {
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

    for (const doc of targetDocs) {
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

    const sentCount = targetDocs.length - failureCount;

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
