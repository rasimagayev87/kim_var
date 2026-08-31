"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb, getAdminStorage } from "@/lib/firebase/admin";
import { resizedVariantPath } from "@/lib/chat-media-path";
import { eventCoverPath } from "@/lib/media-paths";
import { logModerationAction } from "./log";

/** Best-effort on a missing object (a video has no `_200x200`, a re-run
 * deletes nothing) — but logged, never swallowed. Same shape as
 * `deleteStorageObject` in lib/user-account-deletion.ts. */
async function tryDeleteStorageObject(path: string): Promise<void> {
  try {
    await getAdminStorage().bucket().file(path).delete();
  } catch (e) {
    console.warn("tryDeleteStorageObject: delete failed (path may not exist)", { path, error: String(e) });
  }
}

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireEventModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  // `manageFeedback`, not `moderateVenues` — these are complaint
  // queues, not venue moderation, and `support` owns complaints.
  // Unchanged for admin/moderator, who hold both.
  if (!admin || !hasPermission(admin.role, "manageFeedback")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** "Sil" — cancels the reported event AND marks the report resolved,
 * in one action, matching the spec's "Sil (status: cancelled + report
 * status: resolved)". */
export async function resolveEventReport(reportId: string, eventId: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    const db = getAdminDb();
    const eventSnap = await db.collection("venueEvents").doc(eventId).get();

    // The document stays as `cancelled` — it is the moderation record,
    // and deleting it would erase what the report was about. The COVER
    // IMAGE does not stay: a reported event is often reported FOR its
    // image, and a Storage object outlives the document's status
    // completely. Its download token never expires, so "cancelled" left
    // the picture readable by anyone who had the URL.
    //
    // Path derived from the venue owner + event id, never parsed out of
    // the stored `coverImageUrl` — see lib/media-paths.ts and, for why
    // parsing would be unsafe, lib/storage-path.ts.
    const venueId = eventSnap.data()?.venueId as string | undefined;
    if (venueId) {
      const venueSnap = await db.collection("venues").doc(venueId).get();
      const path = eventCoverPath(venueSnap.data()?.ownerId, eventId);
      if (path) {
        // `_200x200` first: it shares the original's download token, so
        // leaving it behind would leave the image reachable.
        const derivative = resizedVariantPath(path);
        if (derivative) await tryDeleteStorageObject(derivative);
        await tryDeleteStorageObject(path);
      }
    }

    await db.collection("venueEvents").doc(eventId).update({
      status: "cancelled",
      // The bytes are gone; leaving the URL would render a broken image
      // in the owner's own history.
      coverImageUrl: null,
    });
    await db.collection("eventReports").doc(reportId).update({ status: "resolved" });

    await logModerationAction({
      actor: check.admin,
      action: "event.cancelled",
      targetType: "event",
      targetId: eventId,
      note: `report ${reportId} üzrə silindi`,
    });
    await logModerationAction({
      actor: check.admin,
      action: "eventReport.statusChanged",
      targetType: "eventReport",
      targetId: reportId,
      note: "status → resolved",
    });

    revalidatePath("/event-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

/** "Rədd et" — dismisses the report, event untouched. */
export async function dismissEventReport(reportId: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("eventReports").doc(reportId).update({ status: "dismissed" });
    await logModerationAction({
      actor: check.admin,
      action: "eventReport.statusChanged",
      targetType: "eventReport",
      targetId: reportId,
      note: "status → dismissed",
    });

    revalidatePath("/event-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
