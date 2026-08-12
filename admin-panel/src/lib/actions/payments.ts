"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";
import type { ActionResult } from "./venues";

/**
 * Closes out a `refund_pending` payment once the admin has actually
 * sent the money back manually (bank transfer, etc.) — no payment
 * provider is wired yet, so nothing here calls a real refund API; this
 * is purely the admin confirming "I did it" so the payment stops
 * showing up in the manual-tracking queue. Same `moderateVenues`
 * permission as venue moderation, since every payment here today
 * originates from a venue-listing decision.
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
