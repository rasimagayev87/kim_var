"use server";

import { revalidatePath } from "next/cache";

import { getCurrentAdmin } from "@/lib/auth/server";
import { getAdminDb } from "@/lib/firebase/admin";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

/** No extra Permission gate (unlike moderation actions) — every admin/
 * moderator session may dismiss their own view of this shared inbox,
 * same as opening the Bell dropdown itself requires nothing beyond a
 * valid session. */
export async function markAdminNotificationRead(id: string): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin) return { ok: false, error: "forbidden" };

  try {
    await getAdminDb().collection("adminNotifications").doc(id).update({ read: true });
    revalidatePath("/", "layout");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function markAllAdminNotificationsRead(): Promise<ActionResult> {
  const admin = await getCurrentAdmin();
  if (!admin) return { ok: false, error: "forbidden" };

  try {
    const db = getAdminDb();
    const snap = await db.collection("adminNotifications").where("read", "==", false).get();
    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, { read: true });
    }
    await batch.commit();
    revalidatePath("/", "layout");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
