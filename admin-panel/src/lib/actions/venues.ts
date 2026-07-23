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
    case "rejected":
      return "venue.rejected";
    case "inactive":
      return "venue.deactivated";
    case "active":
    default:
      // Covers both a pending venue's approval AND reactivating one
      // that was previously deactivated/rejected — both read as
      // "approved" (this venue is visible again) in the audit trail.
      return "venue.approved";
  }
}

export async function setVenueStatus(id: string, status: VenueStatus): Promise<ActionResult> {
  const check = await requireVenueModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("venues").doc(id).update({ status, updatedAt: new Date() });
    await logModerationAction({
      actor: check.admin,
      action: logActionForStatus(status),
      targetType: "venue",
      targetId: id,
      note: `status → ${status}`,
    });
    revalidatePath("/venues");
    revalidatePath(`/venues/${id}`);
    revalidatePath("/dashboard");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
