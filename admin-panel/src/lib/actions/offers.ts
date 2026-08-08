"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import type { ModerationAction } from "@/lib/data/moderation-logs";
import type { OfferStatus } from "@/lib/data/offers";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireOfferModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

function logActionForStatus(status: OfferStatus): ModerationAction {
  switch (status) {
    case "needs_revision":
      return "offer.needsRevision";
    case "rejected":
      return "offer.rejected";
    case "approved":
    default:
      return "offer.approved";
  }
}

/** Same required-note-for-needs_revision contract as `setVenueStatus`
 * — see its doc comment. */
export async function setOfferStatus(id: string, status: OfferStatus, reviewNote?: string): Promise<ActionResult> {
  const check = await requireOfferModeration();
  if ("denied" in check) return check.denied;

  const note = reviewNote?.trim() || null;
  if (status === "needs_revision" && !note) {
    return { ok: false, error: "note-required" };
  }

  try {
    await getAdminDb()
      .collection("offers")
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
      targetType: "offer",
      targetId: id,
      note: note ? `status → ${status}: ${note}` : `status → ${status}`,
    });
    revalidatePath("/offers");
    revalidatePath(`/offers/${id}`);
    revalidatePath("/dashboard");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
