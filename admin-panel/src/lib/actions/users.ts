"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminAuth, getAdminDb } from "@/lib/firebase/admin";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

/**
 * Every mutating action in this module re-checks the session AND the
 * `manageUsers` permission itself — never trusts that the page which
 * rendered the trigger button already gated it. A Server Function is
 * its own network-reachable endpoint; Proxy coverage (or a future
 * route refactor) isn't something this can lean on. See lib/auth/
 * server.ts's doc comment for the same reasoning applied elsewhere.
 */
async function requireUserManagement(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageUsers")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

export async function setUserVerified(uid: string, verified: boolean): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  try {
    // Admin SDK — bypasses firestore.rules entirely, which is exactly
    // the intended path: rules block the CLIENT from ever setting
    // `isVerified` itself (see firestore.rules' users/{userId} block),
    // specifically so only a trusted server actor like this one can.
    await getAdminDb().collection("users").doc(uid).update({ isVerified: verified });
    await logModerationAction({
      actor: check.admin,
      action: verified ? "user.verified" : "user.unverified",
      targetType: "user",
      targetId: uid,
    });
    revalidatePath("/users");
    revalidatePath(`/users/${uid}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function setUserPremium(uid: string, premium: boolean): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  try {
    await getAdminDb().collection("users").doc(uid).update({ premium });
    await logModerationAction({
      actor: check.admin,
      action: premium ? "user.vipGranted" : "user.vipRevoked",
      targetType: "user",
      targetId: uid,
    });
    revalidatePath("/users");
    revalidatePath(`/users/${uid}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function setUserBanned(uid: string, banned: boolean): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  try {
    // Firebase Auth's own `disabled` flag — not a Firestore field.
    // Disabling here invalidates the account's ability to sign in and
    // (via the Admin SDK call below) its existing tokens, unlike a
    // Firestore-only flag a still-signed-in client could just ignore.
    await getAdminAuth().updateUser(uid, { disabled: banned });
    if (banned) {
      await getAdminAuth().revokeRefreshTokens(uid);
    }
    await logModerationAction({
      actor: check.admin,
      action: banned ? "user.banned" : "user.unbanned",
      targetType: "user",
      targetId: uid,
    });
    revalidatePath("/users");
    revalidatePath(`/users/${uid}`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
