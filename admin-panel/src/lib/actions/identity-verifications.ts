"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import type { IdentityVerificationStatus } from "@/lib/data/identity-verifications";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireIdentityVerificationModeration(): Promise<
  { admin: AdminSession } | { denied: ActionResult }
> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateIdentityVerifications")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/**
 * The sole writer of `identityVerified` on approval — same
 * cross-collection-write-lives-in-the-action shape as `setVenueStatus`
 * touching `payments/{paymentId}` alongside `venues/{id}`. A rejection
 * never touches `identityVerified`: it's a grant this action can only
 * ever ADD, matching Faza 0's "dual-path, admin's separate manual
 * grant stays independent" decision — rejecting a KYC resubmission
 * must never revoke a badge some other request or the manual "Kimlik
 * nişanı ver" toggle already granted.
 */
export async function setIdentityVerificationStatus(
  id: string,
  status: Extract<IdentityVerificationStatus, "approved" | "rejected">,
  rejectionReason?: string,
): Promise<ActionResult> {
  const check = await requireIdentityVerificationModeration();
  if ("denied" in check) return check.denied;

  const reason = rejectionReason?.trim() || null;
  if (status === "rejected" && !reason) {
    return { ok: false, error: "note-required" };
  }

  try {
    const db = getAdminDb();
    const ref = db.collection("identityVerifications").doc(id);
    const snap = await ref.get();
    if (!snap.exists) return { ok: false, error: "not-found" };
    if (snap.data()!.status !== "pending") return { ok: false, error: "not-pending" };
    const userId = snap.data()!.userId as string;

    const batch = db.batch();
    batch.update(ref, {
      status,
      rejectionReason: status === "rejected" ? reason : null,
      reviewedAt: new Date(),
      reviewedByAdminId: check.admin.uid,
    });
    if (status === "approved") {
      batch.update(db.collection("users").doc(userId), { identityVerified: true });
    }
    await batch.commit();

    await logModerationAction({
      actor: check.admin,
      action: status === "approved" ? "identityVerification.approved" : "identityVerification.rejected",
      targetType: "identityVerification",
      targetId: id,
      note: reason ?? undefined,
    });

    revalidatePath("/identity-verifications");
    revalidatePath(`/identity-verifications/${id}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
