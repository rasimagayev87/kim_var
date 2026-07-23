"use server";

import { revalidatePath } from "next/cache";

import { hasPermission } from "@/lib/auth/permissions";
import { getCurrentAdmin } from "@/lib/auth/server";
import type { AdminSession } from "@/lib/auth/session";
import { getAdminDb, getAdminStorage } from "@/lib/firebase/admin";
import { listPostComments, type AdminCommentRow } from "@/lib/data/content";
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

/** Best-effort — mirrors `FirebasePostRepository.deletePost`'s own
 * "an orphaned Storage object isn't worth failing the delete over"
 * reasoning on the mobile side. */
async function tryDeleteStorageUrl(url: string | undefined): Promise<void> {
  if (!url) return;
  try {
    await getAdminStorage().bucket().file(storagePathFromUrl(url)).delete();
  } catch {
    // Ignore — see doc comment above.
  }
}

/** Firestore Storage download URLs encode the object path after
 * `/o/` and before the `?` query string, URL-encoded. */
function storagePathFromUrl(url: string): string {
  const match = url.match(/\/o\/([^?]+)/);
  return match ? decodeURIComponent(match[1]) : url;
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

    await postRef.delete();
    // onPostDeleted (Cloud Function) cascades the likes/comments
    // subcollections; Storage media isn't part of that trigger, so
    // it's cleaned up here, same as the mobile app's own owner-delete
    // path.
    await Promise.all([
      tryDeleteStorageUrl(data?.mediaUrl as string | undefined),
      tryDeleteStorageUrl(data?.thumbnailUrl as string | undefined),
    ]);

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
