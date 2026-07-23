"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminRole, AdminSession } from "@/lib/auth/session";
import { getAdminAuth, getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

async function requireAdminManagement(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageAdmins")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/**
 * Promotes an EXISTING Meevima account to admin/moderator by email.
 * Deliberately does not create a brand-new Firebase Auth user the way
 * scripts/bootstrap-admin.ts can — that script exists specifically for
 * standing up the very first admin when nobody can click a button yet;
 * doing the same from a web form would mean handling a password inside
 * a plain input, which is exactly the pattern worth avoiding. If the
 * email doesn't match an existing account, this returns a clear error
 * telling the caller to use the bootstrap script instead.
 */
export async function addAdmin(email: string, role: AdminRole): Promise<ActionResult> {
  const check = await requireAdminManagement();
  if ("denied" in check) return check.denied;

  const trimmedEmail = email.trim().toLowerCase();
  if (!trimmedEmail) {
    return { ok: false, error: "invalid-input" };
  }

  try {
    const auth = getAdminAuth();
    let user;
    try {
      user = await auth.getUserByEmail(trimmedEmail);
    } catch {
      return { ok: false, error: "user-not-found" };
    }

    await auth.setCustomUserClaims(user.uid, { role });

    await getAdminDb().collection("admins").doc(user.uid).set({
      email: trimmedEmail,
      role,
      addedAt: new Date(),
      addedBy: check.admin.email,
    });

    await logModerationAction({
      actor: check.admin,
      action: "admin.added",
      targetType: "admin",
      targetId: user.uid,
      note: `${trimmedEmail} → ${role}`,
    });

    revalidatePath("/admins");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function changeAdminRole(uid: string, role: AdminRole): Promise<ActionResult> {
  const check = await requireAdminManagement();
  if ("denied" in check) return check.denied;

  // Self-demotion is blocked outright — the alternative (letting the
  // very last admin demote themselves to moderator) can strand a
  // project with nobody able to manage admins/broadcast at all. A
  // second admin can always change this account instead.
  if (uid === check.admin.uid) {
    return { ok: false, error: "cannot-change-self" };
  }

  try {
    await getAdminAuth().setCustomUserClaims(uid, { role });
    await getAdminDb().collection("admins").doc(uid).update({ role });
    // Role changes must take effect immediately, not whenever this
    // admin's current session cookie happens to expire — see
    // lib/auth/server.ts's `getCurrentAdmin` doc comment for why
    // `checkRevoked: true` there is what makes this call meaningful.
    await getAdminAuth().revokeRefreshTokens(uid);

    await logModerationAction({
      actor: check.admin,
      action: "admin.roleChanged",
      targetType: "admin",
      targetId: uid,
      note: `→ ${role}`,
    });

    revalidatePath("/admins");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function removeAdmin(uid: string): Promise<ActionResult> {
  const check = await requireAdminManagement();
  if ("denied" in check) return check.denied;

  if (uid === check.admin.uid) {
    return { ok: false, error: "cannot-change-self" };
  }

  try {
    // `setCustomUserClaims(uid, null)` clears every custom claim on the
    // account — right choice here since `role` is the only one this
    // app ever sets, so there's nothing else to preserve.
    await getAdminAuth().setCustomUserClaims(uid, null);
    await getAdminAuth().revokeRefreshTokens(uid);
    await getAdminDb().collection("admins").doc(uid).delete();

    await logModerationAction({
      actor: check.admin,
      action: "admin.removed",
      targetType: "admin",
      targetId: uid,
    });

    revalidatePath("/admins");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
