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
 * Creates a brand-new, admin-only Firebase Auth account and grants it
 * [role] — deliberately NEVER promotes an existing account, the same
 * "fully isolated from the mobile app's user pool" rule
 * `scripts/bootstrap-admin.ts` enforces for the CLI path. Same
 * Firebase project, same Auth namespace as mobile-app end users, but
 * an admin's email must never double as one an end user could also
 * sign in with: if [email] already belongs to ANY account — a
 * mobile-app user or another admin/moderator — this returns
 * `email-taken` instead of silently attaching the role claim to that
 * account.
 */
export async function addAdmin(email: string, password: string, role: AdminRole): Promise<ActionResult> {
  const check = await requireAdminManagement();
  if ("denied" in check) return check.denied;

  const trimmedEmail = email.trim().toLowerCase();
  if (!trimmedEmail || password.length < 6) {
    return { ok: false, error: "invalid-input" };
  }

  try {
    const auth = getAdminAuth();

    try {
      await auth.getUserByEmail(trimmedEmail);
      return { ok: false, error: "email-taken" };
    } catch (error) {
      // `auth/user-not-found` is the expected, good-path outcome here
      // — anything else (network error, malformed query) should still
      // surface instead of being silently treated as "email free".
      if ((error as { code?: string }).code !== "auth/user-not-found") throw error;
    }

    const user = await auth.createUser({ email: trimmedEmail, password, emailVerified: true });

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
