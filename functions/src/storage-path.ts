/**
 * Confining a client-written Storage URL to a server-chosen prefix.
 *
 * TWIN of `admin-panel/src/lib/storage-path.ts`. The two are byte-wise
 * identical in behaviour and held that way by
 * `tests/rules/storage-path.test.ts`, which imports BOTH and asserts
 * they agree on every input including the hostile ones. Duplicated
 * rather than shared because `functions/` and `admin-panel/` are
 * separate Node projects with no common package — the same arrangement
 * as `chat-media.ts` / `chat-media-path.ts`.
 *
 * Used where a path CANNOT be derived from server-known values. Post
 * media is the case: the file name is the upload's microsecond
 * timestamp, allocated before the Firestore document exists, so the
 * stored URL is the only record of which object belongs to the post.
 * Everything else — venue, offer, PinBox, event, story, chat — derives
 * its path instead (`./media-paths`, `./chat-media`), which is
 * strictly stronger and should be preferred wherever it is possible.
 *
 * See the admin-panel twin's doc comment for the arbitrary-deletion
 * vector this closes (P0 / C-1, and its 2026-08-31 recurrence).
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
