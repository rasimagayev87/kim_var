"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb } from "@/lib/firebase/admin";
import type { OfferStatus } from "@/lib/data/offers";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireOfferModeration(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "moderateOffers")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

export async function setOfferStatus(id: string, status: OfferStatus): Promise<ActionResult> {
  const check = await requireOfferModeration();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("offers").doc(id).update({ status, updatedAt: new Date() });
    await logModerationAction({
      actor: check.admin,
      action: status === "rejected" ? "offer.rejected" : "offer.approved",
      targetType: "offer",
      targetId: id,
      note: `status → ${status}`,
    });
    revalidatePath("/offers");
    revalidatePath(`/offers/${id}`);
    revalidatePath("/dashboard");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
