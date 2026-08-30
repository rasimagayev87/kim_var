"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import { isAdminRole, type AdminRole, type AdminSession } from "@/lib/auth/session";
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
/**
 * Runtime validation for the `role` argument (P0 follow-up / RBAC-A).
 *
 * `addAdmin`/`changeAdminRole` declare this parameter as `AdminRole`, but
 * they are Server Actions: the value arrives over the network from a
 * browser and TypeScript's types are erased before it gets here. Nothing
 * previously checked it.
 *
 * Passing an unrecognised role does NOT grant anything — `roleFromClaims`
 * (lib/auth/session.ts) is a strict allowlist, so an unknown claim
 * resolves to `null` and no session is ever minted. The danger runs the
 * other way: `changeAdminRole(uid, "finance")` sets a claim that can
 * never authenticate again, permanently locking that account out of the
 * panel. With one or two admins on this project that can strand the
 * whole thing, and the emergency-token recovery path was deliberately
 * removed (P0 / C-2), leaving only a manual claim repair via the
 * Firebase CLI.
 */
function isValidRole(role: unknown): role is AdminRole {
  return isAdminRole(role);
}

/**
 * How many accounts would still hold the `admin` role if [excludingUid]
 * lost it (P0 follow-up / RBAC last-admin guard).
 *
 * Counted from the `admins` roster rather than from custom claims,
 * because Firebase Auth cannot be queried by claim — that limitation is
 * exactly why this collection exists (see lib/data/admins.ts). The
 * roster is kept in sync by these same three actions, so it is
 * authoritative enough for a "would this leave nobody in charge" check;
 * being wrong in the conservative direction (refusing a legitimate
 * change) is far cheaper than being wrong the other way.
 *
 * `changeAdminRole`/`removeAdmin` already refuse to act on the caller's
 * own account, which makes the last-admin case unreachable TODAY with a
 * single admin. This guard exists so it stays unreachable if that
 * self-check is ever relaxed, and so the failure is a clear error rather
 * than a locked-out project.
 */
async function remainingAdminCount(excludingUid: string): Promise<number> {
  const snap = await getAdminDb().collection("admins").where("role", "==", "admin").get();
  return snap.docs.filter((doc) => doc.id !== excludingUid).length;
}

export async function addAdmin(email: string, password: string, role: AdminRole): Promise<ActionResult> {
  const check = await requireAdminManagement();
  if ("denied" in check) return check.denied;

  if (!isValidRole(role)) {
    return { ok: false, error: "invalid-role" };
  }

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

  if (!isValidRole(role)) {
    return { ok: false, error: "invalid-role" };
  }

  // Demoting the final admin would leave nobody able to manage admins,
  // broadcast, or handle payments — and nobody able to undo it from
  // inside the panel.
  if (role !== "admin" && (await remainingAdminCount(uid)) === 0) {
    return { ok: false, error: "last-admin" };
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

  // Same reasoning as `changeAdminRole`'s own last-admin guard: removing
  // the final admin strands the panel with no way back in.
  if ((await remainingAdminCount(uid)) === 0) {
    return { ok: false, error: "last-admin" };
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
