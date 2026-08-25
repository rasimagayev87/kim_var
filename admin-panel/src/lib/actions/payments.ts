"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";
import type { ActionResult } from "./venues";

/**
 * Closes out a `refund_pending` payment once the admin has actually
 * sent the money back manually (bank transfer, etc.). Most payments
 * never reach here any more — `processPaymentRefund` (functions/src/
 * index.ts) auto-reverses the charge through Epoint's real `/reverse`
 * API and flips straight to `refunded` on success. This is the fallback
 * for the cases that don't (a pre-Epoint-integration payment with no
 * captured transaction id, or Epoint itself rejecting the reversal —
 * both surface an admin notification pointing back here). Same
 * `moderateVenues` permission as venue moderation, since every payment
 * here today originates from a venue-listing decision.
 */
export async function markPaymentRefunded(paymentId: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { ok: false, error: "forbidden" };
  }

  try {
    const ref = getAdminDb().collection("payments").doc(paymentId);
    const snap = await ref.get();
    if (!snap.exists) return { ok: false, error: "not-found" };
    if (snap.data()?.status !== "refund_pending") return { ok: false, error: "not-refund-pending" };

    await ref.update({ status: "refunded", updatedAt: new Date() });
    await logModerationAction({
      actor: admin,
      action: "payment.refunded",
      targetType: "payment",
      targetId: paymentId,
    });
    revalidatePath("/payments");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
