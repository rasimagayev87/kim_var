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

const REVISION_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Same required-note-for-needs_revision contract as `setVenueStatus`,
 * and the same payment side-effects (needs_revision → 7-day deadline +
 * `revision_pending`; rejected → `refund_pending`) — see that
 * function's doc comment for the full reasoning, identical here.
 */
export async function setOfferStatus(id: string, status: OfferStatus, reviewNote?: string): Promise<ActionResult> {
  const check = await requireOfferModeration();
  if ("denied" in check) return check.denied;

  const note = reviewNote?.trim() || null;
  if (status === "needs_revision" && !note) {
    return { ok: false, error: "note-required" };
  }

  try {
    const db = getAdminDb();
    const ref = db.collection("offers").doc(id);
    const snap = await ref.get();
    const paymentId = (snap.data()?.paymentId as string | undefined) || null;

    await ref.update({
      status,
      reviewNote: status === "needs_revision" || status === "rejected" ? note : null,
      reviewedBy: check.admin.uid,
      reviewedAt: new Date(),
      revisionDeadline: status === "needs_revision" ? new Date(Date.now() + REVISION_WINDOW_MS) : null,
      updatedAt: new Date(),
    });

    if (paymentId && (status === "needs_revision" || status === "rejected")) {
      await db
        .collection("payments")
        .doc(paymentId)
        .update({
          status: status === "needs_revision" ? "revision_pending" : "refund_pending",
          updatedAt: new Date(),
        });
    }

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
    if (paymentId) revalidatePath("/payments");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
