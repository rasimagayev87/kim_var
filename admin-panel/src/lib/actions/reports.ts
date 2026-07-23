"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import type { ReportStatus } from "@/lib/data/reports";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireFeedbackManagement(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageFeedback")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

export async function setReportStatus(id: string, status: ReportStatus): Promise<ActionResult> {
  const check = await requireFeedbackManagement();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("reports").doc(id).update({ status });
    await logModerationAction({
      actor: check.admin,
      action: "report.statusChanged",
      targetType: "report",
      targetId: id,
      note: `status → ${status}`,
    });
    revalidatePath("/feedback");
    revalidatePath(`/feedback/${id}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
