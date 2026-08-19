"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";
import type { ActionResult } from "./venues";

/**
 * Closes out a `pending` PinBox payout once the admin has actually sent
 * the venue its share manually — no bank-transfer integration exists
 * (explicit product decision, see `computeMonthlyPinBoxPayouts`'s own
 * doc comment), same "admin confirms, nothing calls a real transfer
 * API" contract as `markPaymentRefunded`.
 */
export async function markPinBoxPayoutPaid(payoutId: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { ok: false, error: "forbidden" };
  }

  try {
    const ref = getAdminDb().collection("venuePayouts").doc(payoutId);
    const snap = await ref.get();
    if (!snap.exists) return { ok: false, error: "not-found" };
    if (snap.data()?.status !== "pending") return { ok: false, error: "not-pending" };

    await ref.update({ status: "paid", paidAt: new Date(), updatedAt: new Date() });
    await logModerationAction({
      actor: admin,
      action: "pinboxPayout.paid",
      targetType: "venuePayout",
      targetId: payoutId,
    });
    revalidatePath("/pinbox-payouts");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
