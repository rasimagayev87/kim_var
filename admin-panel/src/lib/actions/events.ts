"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireEventModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  // `moderateEvents`, not `viewEvents` — the matrix's own view/manage
  // split. A role with view-only access sees this page with the action
  // buttons hidden AND is rejected here, because hiding a button is
  // never the boundary.
  if (!admin || !hasPermission(admin.role, "moderateEvents")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/**
 * Approve a pending event, or reject it.
 *
 * Writes ONLY the status (plus a note on rejection). Everything that
 * follows from publication — the venue's `publishedEventCount`, the
 * period's event quota, the digest intent, the owner's notification —
 * happens in `onVenueEventUpdated`, so the admin panel and the app's
 * own trusted-venue path go through exactly one publish routine
 * instead of two that can drift.
 */
export async function setEventStatus(
  id: string,
  status: "upcoming" | "rejected",
  reviewNote?: string,
): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  const note = reviewNote?.trim() || null;
  // A rejection the owner cannot understand is a disappearance. The
  // approval path needs no note; the rejection path does.
  if (status === "rejected" && !note) return { ok: false, error: "note-required" };

  try {
    const db = getAdminDb();
    const ref = db.collection("venueEvents").doc(id);
    const snap = await ref.get();
    if (!snap.exists) return { ok: false, error: "not-found" };
    if (snap.data()?.status !== "pending") return { ok: false, error: "not-pending" };

    await ref.update({
      status,
      reviewNote: status === "rejected" ? note : null,
      reviewedBy: check.admin.uid,
      reviewedAt: new Date(),
    });

    await logModerationAction({
      actor: check.admin,
      action: status === "rejected" ? "event.rejected" : "event.approved",
      targetType: "event",
      targetId: id,
      note: note ? `status → ${status}: ${note}` : `status → ${status}`,
    });

    revalidatePath("/events");
    revalidatePath(`/events/${id}`);
    return { ok: true };
  } catch {
    return { ok: false, error: "failed" };
  }
}

/**
 * Takedown. `onVenueEventDeleted` handles the cover image, the quota
 * refund (only if it never published) and the reports cleanup.
 */
export async function deleteEvent(id: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("venueEvents").doc(id).delete();
    await logModerationAction({
      actor: check.admin,
      action: "event.deleted",
      targetType: "event",
      targetId: id,
    });
    revalidatePath("/events");
    return { ok: true };
  } catch {
    return { ok: false, error: "failed" };
  }
}

/**
 * Puts a venue's events back under review.
 *
 * Deliberately manual rather than an automatic side-effect of the
 * venue being rejected and re-approved. Venues are usually rejected
 * over a photo or a description, which says nothing about their
 * events, and resetting on every such cycle would re-queue three
 * events for an unrelated reason — moderator time is the scarce
 * resource this whole trust model exists to protect. When a venue IS
 * rejected over its events, this is the deliberate, logged decision to
 * take the trust back.
 */
export async function resetEventTrust(venueId: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("venues").doc(venueId).update({ publishedEventCount: 0 });
    await logModerationAction({
      actor: check.admin,
      action: "event.trustReset",
      targetType: "venue",
      targetId: venueId,
    });
    revalidatePath(`/venues/${venueId}`);
    revalidatePath("/events");
    return { ok: true };
  } catch {
    return { ok: false, error: "failed" };
  }
}
