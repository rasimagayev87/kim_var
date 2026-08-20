"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";
import type { ModerationAction } from "@/lib/data/moderation-logs";
import type { PinBoxStatus } from "@/lib/data/pinboxes";
import { logModerationAction } from "./log";
import type { ActionResult } from "./venues";

function logActionForStatus(status: PinBoxStatus): ModerationAction {
  return status === "rejected" ? "pinbox.rejected" : "pinbox.approved";
}

/**
 * Same moderation-lock contract as `setOfferStatus`/`setVenueStatus`,
 * minus their `needs_revision`/payment side effects — PinBox has no
 * resubmit flow and no flat listing fee (see `pinboxes.ts`'s own doc
 * comment), so this is a plain pending → active/rejected decision, with
 * either direction reversible afterwards (an approved box can still be
 * rejected, and a rejected one re-approved, same "mistakes are
 * recoverable" precedent as offers).
 */
export async function setPinBoxStatus(id: string, status: PinBoxStatus, reviewNote?: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    return { ok: false, error: "forbidden" };
  }

  try {
    const ref = getAdminDb().collection("pinboxes").doc(id);
    await ref.update({
      status,
      reviewNote: status === "rejected" ? reviewNote?.trim() || null : null,
      reviewedBy: admin.uid,
      reviewedAt: new Date(),
      updatedAt: new Date(),
    });

    await logModerationAction({
      actor: admin,
      action: logActionForStatus(status),
      targetType: "pinbox",
      targetId: id,
      note: reviewNote?.trim() ? `status → ${status}: ${reviewNote.trim()}` : `status → ${status}`,
    });
    revalidatePath("/pinboxes");
    revalidatePath(`/pinboxes/${id}`);
    revalidatePath("/dashboard");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
