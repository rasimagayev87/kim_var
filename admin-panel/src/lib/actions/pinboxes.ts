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
  if (status === "needs_revision") return "pinbox.needsRevision";
  return status === "rejected" ? "pinbox.rejected" : "pinbox.approved";
}

/**
 * Same moderation-lock contract as `setOfferStatus`/`setVenueStatus`,
 * minus their `revisionDeadline`/payment-refund side effects — a PinBox
 * listing carries no upfront fee to protect with a deadline or refund
 * (see `pinboxes.ts`'s own doc comment: revenue here is a per-order
 * commission, not a listing fee), so `needs_revision` is just a
 * reason-required send-back with no expiry clock. Either direction is
 * reversible afterwards (an approved box can still be rejected, and a
 * rejected one re-approved, same "mistakes are recoverable" precedent
 * as offers).
 */
export async function setPinBoxStatus(id: string, status: PinBoxStatus, reviewNote?: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    return { ok: false, error: "forbidden" };
  }

  const note = reviewNote?.trim() || null;
  if (status === "needs_revision" && !note) {
    return { ok: false, error: "note-required" };
  }

  try {
    const ref = getAdminDb().collection("pinboxes").doc(id);
    await ref.update({
      status,
      reviewNote: status === "needs_revision" || status === "rejected" ? note : null,
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
