/**
 * Deterministic Storage-path derivation for chat message media.
 *
 * Split into its own module (same shape as `epoint.ts`/`iap.ts`) for
 * one reason: it imports nothing, touches no SDK, and is therefore
 * directly unit-testable — which matters here more than anywhere else
 * in this codebase, because this function IS the security boundary
 * that P0 / C-1 closed. `index.ts` initializes firebase-admin at import
 * time, so anything living there can only be exercised against a full
 * emulator; this can be asserted directly.
 *
 * See [chatMediaPathForMessage] for the vector this replaced.
 */

/** `MessageType` (Dart, message.dart) → the Storage folder and fixed
 * file extension `FirebaseChatRepository._sendMediaMessage` uploads
 * with. Kept in sync BY HAND with that method's own three call sites
 * (`sendImageMessage`/`sendVideoMessage`/`sendAudioMessage`) — the same
 * "duplicate table, two runtimes" shape this codebase already accepts
 * elsewhere (see `venueSubscriptionFeeByCategory`'s doc comment).
 *
 * Deliberately does NOT include `text` or `post`:
 *   - `text` never has media at all.
 *   - `post` (a shared profile-feed post) carries a `mediaUrl` that
 *     points at the ORIGINAL `posts/{uid}/...` object, which belongs to
 *     the post, not to the message. Treating it as chat media is what
 *     made deleting a chat destroy the poster's own post media — a real
 *     data-loss bug in ordinary use, independent of any attack.
 */
const CHAT_MEDIA_SHAPE_BY_TYPE: Record<string, { folder: string; extension: string }> = {
  image: { folder: "chat_photos", extension: "jpg" },
  video: { folder: "chat_videos", extension: "mp4" },
  audio: { folder: "chat_audio", extension: "m4a" },
};

/** The three folders above, for callers that need the set itself
 * (e.g. `forwardChatMedia`'s source-path validation). */
export const CHAT_MEDIA_FOLDERS = Object.values(CHAT_MEDIA_SHAPE_BY_TYPE).map((s) => s.folder);

/**
 * The Storage path for one chat message's own media, computed ENTIRELY
 * from server-known values — or `null` when this message has no chat
 * media of its own to delete.
 *
 * P0 / C-1. This replaces `deleteStorageObjectByUrl(message.mediaUrl)`,
 * which handed a CLIENT-WRITTEN string straight to
 * `bucket.file(path).delete()` on the Admin SDK. The old resolver only
 * looked for a `/o/` separator, so any string containing it resolved to
 * any object in the bucket: one crafted message plus a chat delete
 * could erase every profile photo, venue/offer image, story, post, or
 * identity-verification document in the project, with the deleter's
 * errors silently swallowed.
 *
 * Every component below is either a trigger parameter or a field
 * `firestore.rules` already pins:
 *   - `folder`/`extension` — from `type`, which can only ever select
 *     among the three CHAT folders; an unrecognized type returns
 *     `null`, so nothing is deleted rather than something wrong.
 *   - `chatId`    — the caller's own trigger parameter / document id.
 *   - `senderId`  — `messages` create requires `senderId ==
 *     request.auth.uid`, and the `update` rule's `hasOnly` can never
 *     change it afterwards.
 *   - `messageId` — the message document's own id.
 *
 * Mirrors `FirebaseChatRepository._sendMediaMessage`'s
 * `'$folder/$chatId/$senderId/${messageRef.id}.$extension'` exactly.
 * `forwardMessage` reuses that same `messageRef.id` when calling
 * `forwardChatMedia`, so a forwarded copy lands on the identical shape
 * and is cleaned up by the same derivation.
 *
 * `mediaUrl` is still READ here — but only as a presence flag ("does
 * this message have media at all"), never as a path. Its value cannot
 * influence which object is addressed.
 */
export function chatMediaPathForMessage(
  chatId: string,
  messageId: string,
  data: Record<string, unknown>,
): string | null {
  if (typeof data.mediaUrl !== "string" || !data.mediaUrl) return null;
  if (typeof data.type !== "string") return null;
  const shape = CHAT_MEDIA_SHAPE_BY_TYPE[data.type];
  if (!shape) return null;
  const senderId = data.senderId;
  if (typeof senderId !== "string" || !senderId) return null;
  // A `/` in either id would let a crafted value climb out of the
  // intended prefix. Neither can actually contain one (Firestore
  // document ids forbid `/`, and `chatId` is `{uidA}_{uidB}`), so this
  // is a structural assertion rather than a live filter — kept because
  // the whole point of this function is that its output is trustworthy
  // without the caller re-checking it.
  if (chatId.includes("/") || messageId.includes("/") || senderId.includes("/")) return null;
  return `${shape.folder}/${chatId}/${senderId}/${messageId}.${shape.extension}`;
}

/**
 * P0 / H-4 — whether a chat has been hidden by EVERY participant and
 * may therefore be hard-deleted.
 *
 * "Söhbəti sil" used to delete the shared chat document outright, which
 * cascaded through `onChatDeleted` into both participants' messages and
 * Storage objects — so either side could erase the other's history, and
 * in a harassment case that is the abuser destroying the victim's
 * evidence. It is now a per-user hide (`hiddenFor.{uid} = true`), and
 * the document only actually goes away once nobody wants it any more.
 *
 * Lives here, next to [chatMediaPathForMessage], for the same reason:
 * it is the predicate the deletion decision turns on, and keeping it
 * free of any SDK import means it can be asserted directly instead of
 * only through a full emulator run.
 *
 * Deliberately strict about shape. An empty or malformed
 * `participants` array returns `false` (never delete), because the
 * failure mode of a wrong `true` here is irreversible data loss for
 * two people, while a wrong `false` just leaves a hidden chat document
 * sitting in Firestore costing a few bytes.
 */
export function isChatHiddenByEveryone(
  participants: unknown,
  hiddenFor: unknown,
): boolean {
  if (!Array.isArray(participants) || participants.length === 0) return false;
  if (typeof hiddenFor !== "object" || hiddenFor === null) return false;
  const flags = hiddenFor as Record<string, unknown>;
  return participants.every((uid) => typeof uid === "string" && flags[uid] === true);
}

/**
 * The `_200x200` copy the Resize Images extension writes alongside an
 * original, or `null` when this path can't have one.
 *
 * The extension is configured with an EMPTY `RESIZED_IMAGES_PATH`
 * (`extensions/storage-resize-images.env`), so the derivative lands in
 * the same folder as its original with the size appended to the base
 * name: `chat_photos/a_b/a/m1.jpg` → `chat_photos/a_b/a/m1_200x200.jpg`.
 *
 * This matters for deletion, not display. `REGENERATE_TOKEN=false`
 * means the derivative REUSES the original's download token — that is
 * what lets `app_image.dart` derive a thumbnail URL by string
 * substitution, and it is also what makes an undeleted derivative a
 * real leak rather than a stray byte: whoever held the original's URL
 * can reach the copy by editing one path segment, long after the
 * original was "deleted". Prefix deletes (`deleteStoragePrefix`) never
 * had this problem; every exact-path delete did.
 *
 * Kept in sync BY HAND with `IMG_SIZES` in that `.env` file, and with
 * `resizedImageUrl` in `lib/core/widgets/app_image.dart` — three places
 * that must agree, which is why the size lives in one named constant
 * here rather than inline.
 */
export const RESIZED_IMAGE_SUFFIX = "_200x200";

export function resizedVariantPath(path: unknown): string | null {
  if (typeof path !== "string" || path === "") return null;
  const slash = path.lastIndexOf("/");
  const dot = path.lastIndexOf(".");
  // No extension, or the dot belongs to a directory name rather than
  // the file ("a.b/c") — nothing to append a suffix in front of.
  if (dot <= slash + 1) return null;
  const base = path.slice(0, dot);
  if (base.endsWith(RESIZED_IMAGE_SUFFIX)) return null; // already a derivative
  return `${base}${RESIZED_IMAGE_SUFFIX}${path.slice(dot)}`;
}
