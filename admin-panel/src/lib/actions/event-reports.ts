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

async function requireEventModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateVenues")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/** "Sil" — cancels the reported event AND marks the report resolved,
 * in one action, matching the spec's "Sil (status: cancelled + report
 * status: resolved)". */
export async function resolveEventReport(reportId: string, eventId: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    const db = getAdminDb();
    await db.collection("venueEvents").doc(eventId).update({ status: "cancelled" });
    await db.collection("eventReports").doc(reportId).update({ status: "resolved" });

    await logModerationAction({
      actor: check.admin,
      action: "event.cancelled",
      targetType: "event",
      targetId: eventId,
      note: `report ${reportId} üzrə silindi`,
    });
    await logModerationAction({
      actor: check.admin,
      action: "eventReport.statusChanged",
      targetType: "eventReport",
      targetId: reportId,
      note: "status → resolved",
    });

    revalidatePath("/event-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

/** "Rədd et" — dismisses the report, event untouched. */
export async function dismissEventReport(reportId: string): Promise<ActionResult> {
  const check = await requireEventModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("eventReports").doc(reportId).update({ status: "dismissed" });
    await logModerationAction({
      actor: check.admin,
      action: "eventReport.statusChanged",
      targetType: "eventReport",
      targetId: reportId,
      note: "status → dismissed",
    });

    revalidatePath("/event-reports");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
