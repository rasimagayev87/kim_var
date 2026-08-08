"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import type { ModerationAction } from "@/lib/data/moderation-logs";
import type { VenueStatus } from "@/lib/data/venues";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireVenueModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** `pending` is never a target status this action is called WITH (only
 * ever a starting point), so it's deliberately not a case here — the
 * fallback below covers it anyway. */
function logActionForStatus(status: VenueStatus): ModerationAction {
  switch (status) {
    case "needs_revision":
      return "venue.needsRevision";
    case "rejected":
      return "venue.rejected";
    case "inactive":
      return "venue.deactivated";
    case "approved":
    default:
      // Covers both a pending venue's approval AND reactivating one
      // that was previously deactivated/rejected — both read as
      // "approved" (this venue is visible again) in the audit trail.
      return "venue.approved";
  }
}

/**
 * `reviewNote` is required by the caller when `status` is
 * `needs_revision` (enforced again here, not just in the dialog, since
 * this is a Server Action any client could call directly). It's
 * optional for `rejected` and cleared for every other status, matching
 * the owner-facing contract: only needs_revision/rejected ever show a
 * reason on the mobile side.
 */
export async function setVenueStatus(id: string, status: VenueStatus, reviewNote?: string): Promise<ActionResult> {
  const check = await requireVenueModeration();
  if ("denied" in check) return check.denied;

  const note = reviewNote?.trim() || null;
  if (status === "needs_revision" && !note) {
    return { ok: false, error: "note-required" };
  }

  try {
    await getAdminDb()
      .collection("venues")
      .doc(id)
      .update({
        status,
        reviewNote: status === "needs_revision" || status === "rejected" ? note : null,
        reviewedBy: check.admin.uid,
        reviewedAt: new Date(),
        updatedAt: new Date(),
      });
    await logModerationAction({
      actor: check.admin,
      action: logActionForStatus(status),
      targetType: "venue",
      targetId: id,
      note: note ? `status → ${status}: ${note}` : `status → ${status}`,
    });
    revalidatePath("/venues");
    revalidatePath(`/venues/${id}`);
    revalidatePath("/dashboard");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
