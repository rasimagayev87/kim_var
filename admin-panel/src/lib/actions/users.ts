"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminAuth, getAdminDb } from "@/lib/firebase/admin";
import { deleteUserAccountPermanently } from "@/lib/user-account-deletion";
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

export async function setUserIdentityVerified(uid: string, verified: boolean): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  try {
    // Admin SDK — bypasses firestore.rules entirely, which is exactly
    // the intended path: rules block the CLIENT from ever setting
    // `identityVerified` itself (see firestore.rules' users/{userId}
    // doc comment), specifically so only a trusted server actor like
    // this one can.
    await getAdminDb().collection("users").doc(uid).update({ identityVerified: verified });
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

/**
 * Sends a formal moderation warning — a step short of a ban, for a
 * user whose behavior needs addressing without disabling their
 * account outright. Writes straight to `users/{uid}/notifications`
 * (Admin SDK, same as `sendBroadcast`) with structured `metadata`
 * rather than raw `title`/`body`, so the mobile client's
 * `notification_localizer.dart` renders it in the recipient's own
 * app language instead of frozen Azerbaijani text — same contract
 * `notifyUser` (functions/src/index.ts) uses for every other
 * server-authored notification. Deliberately NOT gated behind any
 * `notificationPreferences` toggle (unlike `sendBroadcast`'s
 * `system`/`promotion`/`announcement`) — a moderation warning isn't
 * opt-in content, same stance as e.g. `venueRejected`/`pinboxRejected`.
 */
export async function sendUserWarning(uid: string, reason: string): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  const trimmedReason = reason.trim();
  if (!trimmedReason) return { ok: false, error: "invalid-input" };

  try {
    await getAdminDb().collection("users").doc(uid).collection("notifications").add({
      type: "warning",
      metadata: { reason: trimmedReason },
      isRead: false,
      createdAt: new Date(),
    });
    await logModerationAction({
      actor: check.admin,
      action: "user.warned",
      targetType: "user",
      targetId: uid,
      note: trimmedReason,
    });
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
    // `bannedUsers/{uid}` tombstone (Düzəliş Prompt 11 / Y-1) — this
    // Auth-only mutation was invisible to mobile-side Firestore Rules
    // and Cloud Functions, which don't check Auth's `disabled`/
    // revocation status by default (only the admin panel's own session
    // -cookie verification does, via `checkRevoked: true`). Writing a
    // matching Firestore-visible signal is what lets `isActiveUser()`
    // (firestore.rules) and `assertActiveUser()` (functions/src/index.ts)
    // actually reject a banned mobile user's still-valid cached token on
    // its next write/call attempt, independent of the token's own
    // freshness. Kept as a SEPARATE collection rather than a field on
    // `users/{uid}` itself because that doc's read rule is `if
    // request.auth != null` (any signed-in user can read the whole
    // document) — a `banned` field there would leak ban status to
    // anyone viewing the profile.
    const bannedUserRef = getAdminDb().collection("bannedUsers").doc(uid);
    if (banned) {
      await bannedUserRef.set({ bannedAt: new Date() });
    } else {
      await bannedUserRef.delete();
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

/**
 * Full permanent deletion — Auth record + every Firestore document +
 * every Storage object this account owns. Exists specifically to close
 * the gap deleting from the Firebase Console's Authentication tab
 * leaves behind: that only removes the Auth record, never the
 * Firestore data, since there's no `deleteAccount`-equivalent trigger
 * for a Console-initiated deletion (see `deleteUserAccountPermanently`'s
 * own doc comment for the full reasoning). `username`/`email` are
 * accepted from the caller (not re-read here) purely for a readable
 * moderation-log note — by the time this returns, the doc they'd
 * otherwise be read from no longer exists.
 *
 * No confirmation/undo at this layer — the UI trigger (`UserDetailActions`)
 * is responsible for that; this action performs the deletion the moment
 * it's called.
 */
export async function deleteUserAccount(uid: string, label: string): Promise<ActionResult> {
  const check = await requireUserManagement();
  if ("denied" in check) return check.denied;

  try {
    await deleteUserAccountPermanently(uid);
    await logModerationAction({
      actor: check.admin,
      action: "user.deleted",
      targetType: "user",
      targetId: uid,
      note: label,
    });
    revalidatePath("/users");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
