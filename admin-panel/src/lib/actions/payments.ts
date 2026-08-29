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

/**
 * Düzəliş Prompt 6 / K-11, PAY-9 — the admin-driven refund entry point
 * for the three payment types that had NO refund path at all before
 * this: `boost_fee`, `venue_premium`, `pinbox_order` (`venue_subscription`/
 * `offer_placement_fee` already reach `refund_pending` through
 * `setVenueStatus`/`setOfferStatus` rejecting the listing — this exists
 * specifically for the types nothing else ever set `refund_pending` on).
 *
 * Deliberately just the status flip, same shape as `setVenueStatus`/
 * `setOfferStatus`'s own `refund_pending` write — this Next.js server
 * action has no access to the Epoint secrets (`functions/src/index.ts`'
 * `epointPublicKey`/`epointPrivateKey`/`epointEnv` are Cloud Functions
 * secrets, not wired into the admin panel's own environment), so the
 * actual `/reverse` call and the entitlement reversal it now also does
 * (boost `boostedUntil` cleared, venue premium `isPremium`/
 * `premiumExpiresAt` rolled back, PinBox `venuePayouts` cancelled) both
 * happen in the EXISTING `processPaymentRefund` Firestore trigger —
 * this just gives that trigger something to react to for these three
 * types, reusing 100% of the already-built automatic-refund mechanism
 * rather than duplicating it.
 *
 * UI for this (a "Geri qaytar" button on the relevant payment types) is
 * Prompt 9's scope — this action is ready to be wired up to one.
 */
export async function initiateRefund(paymentId: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { ok: false, error: "forbidden" };
  }

  try {
    const ref = getAdminDb().collection("payments").doc(paymentId);
    const snap = await ref.get();
    if (!snap.exists) return { ok: false, error: "not-found" };
    if (snap.data()?.status !== "completed") return { ok: false, error: "not-refundable" };

    await ref.update({ status: "refund_pending", updatedAt: new Date() });
    await logModerationAction({
      actor: admin,
      action: "payment.refund_initiated",
      targetType: "payment",
      targetId: paymentId,
    });
    revalidatePath("/payments");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
