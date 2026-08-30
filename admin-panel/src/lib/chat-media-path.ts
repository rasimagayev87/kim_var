/**
 * Deterministic Storage-path derivation for chat message media —
 * the admin panel's copy of `functions/src/chat-media.ts`.
 *
 * Duplicated rather than shared because `functions/` and `admin-panel/`
 * are separate Node projects with no common package, the same
 * "duplicate table, two runtimes" shape this codebase already accepts
 * elsewhere (see `RESERVED_USERNAMES` in functions/src/index.ts). The
 * two implementations are held in sync by a parity test
 * (`tests/rules/chat-media-path.test.ts`) that asserts they return
 * byte-identical output for the same inputs, including the hostile
 * ones — a duplicated security boundary is only safe if drift is
 * detectable.
 *
 * No imports on purpose: this must stay unit-testable from outside the
 * Next.js module graph (no `server-only`, no `@/` alias), which is also
 * what lets the parity test import it at all.
 *
 * See [chatMediaPathForMessage] for the vulnerability this closes.
 */

const CHAT_MEDIA_SHAPE_BY_TYPE: Record<string, { folder: string; extension: string }> = {
  image: { folder: "chat_photos", extension: "jpg" },
  video: { folder: "chat_videos", extension: "mp4" },
  audio: { folder: "chat_audio", extension: "m4a" },
};

/**
 * The Storage path for one chat message's own media, computed entirely
 * from server-known values — or `null` when this message has no chat
 * media of its own to delete.
 *
 * This file previously resolved the path by pattern-matching the
 * message's `mediaUrl` field, which the CLIENT writes:
 *
 *   const match = url.match(/\/o\/([^?]+)/);
 *   await deleteStorageFile(decodeURIComponent(match[1]));
 *
 * Any string containing "/o/" therefore addressed any object in the
 * bucket, and this runs under the Admin SDK. The exploit needs no
 * privilege at all — an attacker plants messages whose `mediaUrl`
 * points at, say, `identity_verifications/{victim}/{req}/selfie.jpg`,
 * then gets their own account deleted by an admin (spam until banned,
 * or simply ask support). The admin's click then erases arbitrary
 * objects: other users' profile photos, venue imagery, KYC documents.
 * That is the same finding (P0 / C-1) already fixed on the Cloud
 * Functions side; this file reintroduced it independently.
 *
 * `type: 'post'` returns `null`, and that is a fix rather than an
 * omission: a shared-post message's `mediaUrl` points at the ORIGINAL
 * `posts/{uid}/...` object, so the URL-based version also destroyed the
 * post author's own media whenever some other account that had shared
 * their post was deleted.
 *
 * `mediaUrl` is still read, but only as a presence flag ("does this
 * message have media at all") — its value cannot influence which object
 * is addressed.
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
  if (chatId.includes("/") || messageId.includes("/") || senderId.includes("/")) return null;
  return `${shape.folder}/${chatId}/${senderId}/${messageId}.${shape.extension}`;
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
