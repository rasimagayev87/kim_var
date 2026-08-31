"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb, getAdminStorage } from "@/lib/firebase/admin";
import { listPostComments, type AdminCommentRow } from "@/lib/data/content";
import { resizedVariantPath } from "@/lib/chat-media-path";
import { confinedStoragePath, postMediaPrefix } from "@/lib/storage-path";
import { logModerationAction } from "./log";

export interface ActionResult {
  ok: boolean;
  error?: string;
}

/**
 * Content moderation (deleting posts/comments) is gated by
 * `manageFeedback`, NOT `manageUsers` — deliberately. Moderators get
 * `manageFeedback` but not `manageUsers` (see lib/auth/permissions.ts),
 * and the spec explicitly requires them to be able to delete posts/
 * comments while having no user-management access at all. Putting this
 * behind `manageUsers` would lock moderators out of a capability the
 * spec says they need.
 */
async function requireFeedbackManagement(): Promise<{ admin: AdminSession } | { denied: ActionResult }> {
  const admin = await getCurrentAdmin();
  if (!admin || !hasPermission(admin.role, "manageFeedback")) {
    return { denied: { ok: false, error: "forbidden" } };
  }
  return { admin };
}

/**
 * Deletes ONE post-media object, plus the `_200x200` derivative the
 * Resize Images extension wrote next to it.
 *
 * [url] is a CLIENT-WRITTEN field (`posts/{id}.mediaUrl` /
 * `.thumbnailUrl`), so it never reaches `bucket.file()` unchecked:
 * [confinedStoragePath] pins the resolved path under [allowedPrefix],
 * which the caller computes from the post document's own `userId`.
 * See lib/storage-path.ts for the arbitrary-object-deletion vector
 * that closes, and why posts cannot use `chat-media-path.ts`'s
 * stronger "derive the path outright" approach.
 *
 * The derivative matters as much as the original: the Resize Images
 * extension runs with `REGENERATE_TOKEN=false`, so the copy REUSES the
 * original's download token. Whoever kept the original URL reaches the
 * surviving thumbnail by editing one path segment, with no Firebase
 * session at all — a moderator-deleted image that is still readable is
 * a failed moderation action, not a stray object. `functions/src/index
 * .ts`'s `deleteStorageFile` and `user-account-deletion.ts`'s own copy
 * both already did this; this call site was the one that did not.
 */
async function tryDeletePostMedia(url: string | undefined, allowedPrefix: string): Promise<void> {
  if (!url) return;
  const path = confinedStoragePath(url, allowedPrefix);
  if (path === null) {
    // Not an accident worth hiding. Either the stored URL is malformed,
    // or it points somewhere this post has no business addressing —
    // and the second case is an attempted arbitrary-object deletion,
    // which is exactly the event that must not vanish into a bare
    // `catch {}`. Nothing is deleted either way.
    console.warn("tryDeletePostMedia: refusing URL outside the post's own Storage prefix", {
      allowedPrefix,
      // The URL can carry a live download token, so only its shape is
      // logged — enough to tell "malformed" from "wrong folder"
      // without writing a usable credential into the log.
      urlPrefix: url.slice(0, 80),
    });
    return;
  }

  const derivative = resizedVariantPath(path);
  if (derivative) await deleteStorageObject(derivative);
  await deleteStorageObject(path);
}

/** Best-effort on a MISSING object (a video has no `_200x200`, a
 * re-run deletes nothing) — but logged, never swallowed. Every path
 * reaching here has already been confined, so an unexpected failure is
 * a real bug worth seeing. Same shape as `deleteStorageObject` in
 * lib/user-account-deletion.ts. */
async function deleteStorageObject(path: string): Promise<void> {
  try {
    await getAdminStorage().bucket().file(path).delete();
  } catch (e) {
    console.warn("deleteStorageObject: delete failed (path may not exist)", { path, error: String(e) });
  }
}

/** On-demand comment fetch for the client-side "Şərhlərə bax" sheet —
 * a read, but still routed through a Server Action (not exposed as a
 * plain data-layer import) so it goes through the same permission
 * check as the delete actions rather than being callable unchecked. */
export async function fetchPostComments(postId: string): Promise<AdminCommentRow[] | { error: string }> {
  const check = await requireFeedbackManagement();
  if ("denied" in check) return { error: check.denied.error ?? "forbidden" };
  return listPostComments(postId);
}

export async function deletePost(postId: string, uid: string): Promise<ActionResult> {
  const check = await requireFeedbackManagement();
  if ("denied" in check) return check.denied;

  try {
    const postRef = getAdminDb().collection("posts").doc(postId);
    const doc = await postRef.get();
    const data = doc.data();

    // The confinement prefix comes from the DOCUMENT's own `userId`,
    // never from this action's `uid` argument. A Server Action's
    // arguments arrive over the wire and are shaped by the caller;
    // `data.userId` was read from Firestore here, and `firestore
    // .rules` pinned it to the author's own uid at create time. Using
    // the argument would hand the prefix — the entire security
    // boundary — back to the request.
    const ownerUid = typeof data?.userId === "string" ? data.userId : null;

    await postRef.delete();
    // onPostDeleted (Cloud Function) cascades the likes/comments
    // subcollections; Storage media isn't part of that trigger, so
    // it's cleaned up here, same as the mobile app's own owner-delete
    // path.
    if (ownerUid === null) {
      // No document (already deleted), or one with no author. There is
      // no trustworthy prefix to confine against, so nothing is
      // deleted — the Firestore doc is gone either way, and an orphan
      // object is a far smaller problem than an unconfined delete.
      console.warn("deletePost: post document had no userId; skipping media cleanup", { postId });
    } else {
      const prefix = postMediaPrefix(ownerUid);
      await Promise.all([
        tryDeletePostMedia(data?.mediaUrl as string | undefined, prefix),
        tryDeletePostMedia(data?.thumbnailUrl as string | undefined, prefix),
      ]);
    }

    await logModerationAction({
      actor: check.admin,
      action: "post.deleted",
      targetType: "post",
      targetId: postId,
      note: `owner: ${uid}`,
    });
    revalidatePath(`/users/${uid}`);
    revalidatePath("/feedback");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}

export async function deleteComment(postId: string, commentId: string, uid: string): Promise<ActionResult> {
  const check = await requireFeedbackManagement();
  if ("denied" in check) return check.denied;

  try {
    // onCommentDeleted (Cloud Function) handles its own likes
    // subcollection cascade + decrementing the post's commentsCount —
    // this only needs to remove the comment doc itself.
    await getAdminDb().collection("posts").doc(postId).collection("comments").doc(commentId).delete();

    await logModerationAction({
      actor: check.admin,
      action: "comment.deleted",
      targetType: "comment",
      targetId: commentId,
      note: `post: ${postId}, author: ${uid}`,
    });
    revalidatePath(`/users/${uid}`);
    revalidatePath("/feedback");
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "unknown-error" };
  }
}
