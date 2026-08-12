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

/** Separate from [requireVenueModeration] — granting premium is a
 * monetization decision, not content moderation, so it's gated behind
 * `manageVenues` (admin-only) rather than `moderateVenues` (which
 * moderators also hold). Mirrors `manageUsers` guarding
 * `setUserPremium` in actions/users.ts for the same reason. */
async function requireVenueManagement(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageVenues")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** `pending` is never a target status this action is called WITH (only
 * ever a starting point), so it's deliberately not a case here — the
 * fallback below covers it anyway. */
function logActionForStatus(status: VenueStatus): ModerationAction {
  switch (status) {
    case "needs_revision":
      return "venue.needsRevision";
    case "rejected":
      return "venue.rejected";
    case "inactive":
      return "venue.deactivated";
    case "approved":
    default:
      // Covers both a pending venue's approval AND reactivating one
      // that was previously deactivated/rejected — both read as
      // "approved" (this venue is visible again) in the audit trail.
      return "venue.approved";
  }
}

const REVISION_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * `reviewNote` is required by the caller when `status` is
 * `needs_revision` (enforced again here, not just in the dialog, since
 * this is a Server Action any client could call directly). It's
 * optional for `rejected` and cleared for every other status, matching
 * the owner-facing contract: only needs_revision/rejected ever show a
 * reason on the mobile side.
 *
 * Also drives the venue-listing payment side of the moderation
 * decision, when the venue has a `paymentId` (older venues predating
 * the payment feature won't): `needs_revision` starts a 7-day
 * `revisionDeadline` and marks the payment `revision_pending`;
 * `rejected` marks it `refund_pending`, which `processPaymentRefund`
 * (Cloud Function) picks up for the admin's manual-tracking queue —
 * see the Ödənişlər page. Every other status clears `revisionDeadline`
 * and leaves the payment alone.
 */
export async function setVenueStatus(id: string, status: VenueStatus, reviewNote?: string): Promise<ActionResult> {
  const check = await requireVenueModeration();
  if ("denied" in check) return check.denied;

  const note = reviewNote?.trim() || null;
  if (status === "needs_revision" && !note) {
    return { ok: false, error: "note-required" };
  }

  try {
    const db = getAdminDb();
    const ref = db.collection("venues").doc(id);
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
      targetType: "venue",
      targetId: id,
      note: note ? `status → ${status}: ${note}` : `status → ${status}`,
    });
    revalidatePath("/venues");
    revalidatePath(`/venues/${id}`);
    revalidatePath("/dashboard");
    if (paymentId) revalidatePath("/payments");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

/** Manual premium grant — the same "no real payment yet" stopgap the
 * mobile app's owner-facing "Məkanı premium et" menu points at (see
 * `discover_tab.dart`'s `_openVenuePremiumMenu`). Until a real payment
 * flow exists, this is the only way a venue's `isPremium` flag gets
 * set — mirrors `setUserPremium` in actions/users.ts. */
export async function setVenuePremium(id: string, premium: boolean): Promise<ActionResult> {
  const check = await requireVenueManagement();
  if ("denied" in check) return check.denied;

  try {
    const updates: Record<string, unknown> = { isPremium: premium, updatedAt: new Date() };
    // Re-granting after a revoke resets this to the new grant date —
    // nothing tracks premium history beyond "currently on since X".
    if (premium) updates.premiumSince = new Date();
    await getAdminDb().collection("venues").doc(id).update(updates);
    await logModerationAction({
      actor: check.admin,
      action: premium ? "venue.premiumGranted" : "venue.premiumRevoked",
      targetType: "venue",
      targetId: id,
    });
    revalidatePath("/venues");
    revalidatePath(`/venues/${id}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
