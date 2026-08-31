/**
 * Confining a client-written Storage URL to a server-chosen prefix.
 *
 * ── The bug this exists to make impossible ─────────────────────────
 *
 * `deletePost` (lib/actions/content.ts) used to do this:
 *
 *     const match = url.match(/\/o\/([^?]+)/);
 *     await bucket.file(decodeURIComponent(match[1])).delete();
 *
 * where `url` was `posts/{id}.mediaUrl` — a field the POST'S AUTHOR
 * writes. `firestore.rules` only constrains it to start with this
 * project's bucket (`isOwnStorageUrl`); everything after `/o/` is
 * whatever the author typed. So an author could store
 *
 *     https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9
 *       .firebasestorage.app/o/identity_verifications%2F{victim}%2F{req}%2Ffront.jpg
 *
 * get the post reported, and the moderator's "Sil" click would delete
 * a DIFFERENT user's KYC evidence with Admin SDK privileges — Storage
 * Rules bypassed entirely, irreversibly, with the error swallowed by a
 * bare `catch {}` so nobody ever saw it. Any object in the bucket was
 * reachable: profile photos, venue/offer images, stories, other posts.
 *
 * This is the SAME vector as P0 / C-1, which was fixed in
 * `functions/src/chat-media.ts` and missed here. Third occurrence of a
 * pattern is why this module exists rather than three inline guards.
 *
 * ── Why this file does NOT recompute the path ──────────────────────
 *
 * `chat-media.ts` solves the identical problem by DERIVING the path
 * from server-known values (`chat_photos/{chatId}/{senderId}/{messageId}.jpg`)
 * and never reading the URL at all. That is the stronger fix and it is
 * the right one wherever it is available.
 *
 * It is not available for posts. Post media is uploaded BEFORE the
 * Firestore document exists, so the file name is a timestamp, not the
 * post id:
 *
 *     // lib/features/post_share/data/repositories/firebase_post_repository.dart:36
 *     final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
 *     final storageRef = _storage.ref('posts/$userId/$fileName');
 *
 * `createPost` then calls `_posts.add({...})`, which allocates the id
 * afterwards. Nothing server-side can reconstruct that timestamp, so
 * the URL is the only record of which object belongs to the post.
 * Changing the upload scheme would need a client release plus a
 * migration of existing objects, and would break username-era builds
 * already in the store.
 *
 * So the URL stays the source of the path, and the path is CONFINED
 * instead: it must fall under a prefix the server computed from data
 * it read itself. For posts that prefix is `posts/{post.userId}/`,
 * where `userId` comes from the Firestore document, never from the
 * URL. The confinement is airtight even though the derivation is not,
 * because the two ends agree by construction:
 *
 *   - `firestore.rules` (`posts` create) requires
 *     `request.auth.uid == request.resource.data.userId`
 *   - `storage.rules` (`/posts/{userId}/{fileName}`) requires
 *     `request.auth.uid == userId`
 *
 * i.e. the folder segment and the document's `userId` are the same
 * account by rule, not by convention. The worst an attacker can now
 * achieve is deleting an object inside their OWN `posts/{uid}/`
 * folder — which `storage.rules:265` already lets them do directly
 * from the client SDK. Zero privilege gained.
 *
 * ── No imports, on purpose ─────────────────────────────────────────
 *
 * Same reasoning as `chat-media-path.ts` next door: no `server-only`,
 * no `@/` alias, no SDK. That is what lets `tests/rules/storage-path
 * .test.ts` import it directly and assert the hostile inputs, instead
 * of this boundary being reachable only through a live Storage call.
 */

/**
 * The object path encoded in a Firebase Storage download URL, or
 * `null` when [url] is not one.
 *
 * Returns `null` rather than the input on a non-match. The old version
 * returned `url` itself, which meant a malformed string was handed to
 * `bucket.file()` as if it were a path — failing open in the one
 * direction that matters.
 */
export function storagePathFromDownloadUrl(url: unknown): string | null {
  if (typeof url !== "string" || url === "") return null;
  const marker = "/o/";
  const markerIndex = url.indexOf(marker);
  if (markerIndex === -1) return null;

  const pathStart = markerIndex + marker.length;
  const queryIndex = url.indexOf("?", pathStart);
  const encoded = queryIndex === -1 ? url.slice(pathStart) : url.slice(pathStart, queryIndex);
  if (encoded === "") return null;

  let decoded: string;
  try {
    decoded = decodeURIComponent(encoded);
  } catch {
    // Malformed percent-encoding — `decodeURIComponent` throws URIError.
    return null;
  }
  return decoded === "" ? null : decoded;
}

/**
 * [storagePathFromDownloadUrl], but only when the result actually
 * lives under [allowedPrefix]. `null` otherwise — and `null` must
 * always mean "delete nothing", never "delete something else".
 *
 * [allowedPrefix] must be SERVER-computed (read from Firestore, or
 * built from a trigger parameter). Passing a prefix that itself came
 * from client input would reduce this to the bug it replaces.
 *
 * Traversal is rejected outright rather than normalized. A path
 * containing `..` or an empty segment (`//`) has no legitimate reason
 * to exist here — every real path is written by the Firebase SDK from
 * a literal template — and `bucket.file()` does not normalize the way
 * a filesystem would, so quietly "cleaning" such a path would be
 * guessing at intent. Refusing is the only answer that cannot be
 * wrong.
 */
export function confinedStoragePath(url: unknown, allowedPrefix: string): string | null {
  if (!allowedPrefix.endsWith("/")) {
    // A prefix without its trailing slash would let `posts/abc/` also
    // match `posts/abcdef/...` — a different user's folder whose uid
    // merely starts with the same characters.
    throw new Error(`confinedStoragePath: allowedPrefix must end with "/" (got ${JSON.stringify(allowedPrefix)})`);
  }
  const path = storagePathFromDownloadUrl(url);
  if (path === null) return null;
  if (path.includes("..") || path.includes("//")) return null;
  if (!path.startsWith(allowedPrefix)) return null;
  // A prefix match alone still allows `posts/{uid}/` + `` — the folder
  // itself, with no file name.
  if (path.length === allowedPrefix.length) return null;
  return path;
}

/** Storage folder holding one user's post media — see this module's
 * doc comment for why this is a confinement prefix and not a full
 * path derivation. [userId] must come from the post DOCUMENT. */
export function postMediaPrefix(userId: string): string {
  return `posts/${userId}/`;
}
