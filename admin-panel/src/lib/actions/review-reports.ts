"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireReviewModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** "Sil" — unlike `resolveEventReport` (which soft-cancels the
 * event), a review has no "hidden" state to fall back to (see
 * `Review`'s own doc comment: neither the author nor the venue owner
 * can remove one directly, this admin action is the only path), so
 * this actually deletes the `reviews/{reviewId}` doc. That delete
 * fires `onReviewWritten` (functions/src/index.ts) the same as any
 * other review write, so the venue's `ratingAverage`/`ratingCount`
 * stay correct automatically. */
export async function resolveReviewReport(reportId: string, reviewId: string): Promise<ActionResult> {
  const check = await requireReviewModeration();
  if ("denied" in check) return check.denied;

  try {
    const db = getAdminDb();
    await db.collection("reviews").doc(reviewId).delete();
    await db.collection("reviewReports").doc(reportId).update({ status: "resolved" });

    await logModerationAction({
      actor: check.admin,
      action: "review.deleted",
      targetType: "review",
      targetId: reviewId,
      note: `report ${reportId} üzrə silindi`,
    });
    await logModerationAction({
      actor: check.admin,
      action: "reviewReport.statusChanged",
      targetType: "reviewReport",
      targetId: reportId,
      note: "status → resolved",
    });

    revalidatePath("/review-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

/** "Rədd et" — dismisses the report, review untouched. */
export async function dismissReviewReport(reportId: string): Promise<ActionResult> {
  const check = await requireReviewModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("reviewReports").doc(reportId).update({ status: "dismissed" });
    await logModerationAction({
      actor: check.admin,
      action: "reviewReport.statusChanged",
      targetType: "reviewReport",
      targetId: reportId,
      note: "status → dismissed",
    });

    revalidatePath("/review-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
