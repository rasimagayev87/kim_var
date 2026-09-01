"use server";

import { FieldValue } from "firebase-admin/firestore";
import { revalidatePath } from "next/cache";

import { hasPermission, type Permission } from "@/lib/auth/permissions";
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
async function requireUserPermission(
  permission: Permission,
): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, permission)) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

export async function setUserIdentityVerified(uid: string, verified: boolean): Promise<ActionResult> {
  const check = await requireUserPermission("manageUsers");
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
  // Stays on `manageUsers` (admin only) rather than moving to
  // `manageSubscriptions` alongside `setVenuePremium`: this is reached
  // from the user detail page, which `finance` cannot open at all
  // (`viewUsers: false`). Granting the action without the screen would
  // be a permission that reads as available and never is.
  const check = await requireUserPermission("manageUsers");
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
  const check = await requireUserPermission("manageUsers");
  if ("denied" in check) return check.denied;

  const trimmedReason = reason.trim();
  if (!trimmedReason) return { ok: false, error: "invalid-input" };
  // Admin SDK writes bypass `firestore.rules`, so every other cap in
  // this product does not apply here — same reasoning as
  // `BROADCAST_BODY_MAX`.
  if (trimmedReason.length > 500) return { ok: false, error: "too-long" };

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
  // `banUsers`, not `manageUsers` — moderators ban but never edit a
  // profile or delete an account.
  const check = await requireUserPermission("banUsers");
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
    //
    // SOURCE OF TRUTH: `bannedUsers/{uid}`. Everything that ENFORCES a
    // ban reads it — `isActiveUser()` in firestore.rules and
    // `assertActiveUser()` in functions/src/index.ts.
    //
    // `users/{uid}/private/data.banned` is a READ-SIDE MIRROR of the
    // same fact and nothing more. It exists because the Discover and
    // nearby candidate filters have to exclude banned accounts from
    // hundreds of candidates per call, and consulting `bannedUsers`
    // there would mean one extra document read per candidate on the
    // app's most expensive endpoint; `withPrivateData` has already
    // fetched the private document, so the mirror is free. It lives on
    // the private doc rather than the public one for the same reason
    // this collection exists at all (see the paragraph above): a
    // `banned` field on `users/{uid}` would expose ban status to
    // anyone who can view a profile. `serverOnlyFields()` in
    // firestore.rules keeps the owner from clearing it.
    //
    // IF THE TWO EVER DISAGREE, THE TOMBSTONE WINS. A stale mirror can
    // only leave a banned account visible in a list; it can never
    // grant a permission, because no rule and no callable consults it.
    // Do not turn this field into an authorization input.
    //
    // Both writes go in ONE batch so the pair cannot half-apply.
    const db = getAdminDb();
    const batch = db.batch();
    const bannedUserRef = db.collection("bannedUsers").doc(uid);
    const privateRef = db.collection("users").doc(uid).collection("private").doc("data");
    if (banned) {
      batch.set(bannedUserRef, { bannedAt: new Date() });
      batch.set(privateRef, { banned: true }, { merge: true });
    } else {
      batch.delete(bannedUserRef);
      // Removed rather than set to `false` — an absent field and
      // `false` read identically at every consumer (`!== true`), and
      // leaving a tombstone-shaped `banned: false` behind on every
      // account that was ever unbanned serves nothing.
      //
      // `set`/`merge`, not `update`: `update` fails when the document
      // does not exist, and that failure would take the whole batch
      // with it — an admin unable to lift a ban because the account
      // never had a private doc is a worse outcome than a redundant
      // write.
      batch.set(privateRef, { banned: FieldValue.delete() }, { merge: true });
    }
    await batch.commit();
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
  // `deleteUsers` — irreversible, admin only. Deliberately narrower
  // than `banUsers`: a ban is undoable, this is not.
  const check = await requireUserPermission("deleteUsers");
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
