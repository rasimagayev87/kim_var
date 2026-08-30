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
