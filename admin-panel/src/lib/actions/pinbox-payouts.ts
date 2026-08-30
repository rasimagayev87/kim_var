"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";
import { isLastDayOfBakuMonth } from "@/lib/pinbox-payout-window";
import { logModerationAction } from "./log";
import type { ActionResult } from "./venues";

/**
 * Closes out a `pending` PinBox obligation once the admin has actually
 * sent the venue its share manually — no bank-transfer integration
 * exists (explicit product decision), same "admin confirms, nothing
 * calls a real transfer API" contract as `markPaymentRefunded`.
 *
 * Only allowed on the last calendar day of the month (Baku time) — the
 * UI already disables the button outside that window, but this is the
 * real enforcement point, since a Server Action can be invoked directly
 * regardless of what the disabled button shows.
 */
export async function markPinBoxPayoutPaid(payoutId: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "managePayments")) {
    return { ok: false, error: "forbidden" };
  }

  if (!isLastDayOfBakuMonth()) {
    return { ok: false, error: "not-last-day" };
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
