/**
 * The admin panel's post-media deletion boundary
 * (`admin-panel/src/lib/storage-path.ts`).
 *
 * Same shape and same reason as `chat-media-path.test.ts`: pure
 * functions, no emulator, kept in this suite so one command still
 * proves the whole security boundary.
 *
 * These are negative tests above all. The bug being closed is that
 * `deletePost` handed a CLIENT-WRITTEN `mediaUrl` straight to
 * `bucket.file(...).delete()` on the Admin SDK, so the cases that
 * matter are the ones where a valid-looking URL points somewhere the
 * post has no business addressing.
 */
import { strict as assert } from "node:assert";
import { describe, test } from "node:test";

import {
  confinedStoragePath,
  postMediaPrefix,
  storagePathFromDownloadUrl,
} from "../../admin-panel/src/lib/storage-path";

const BUCKET = "https://firebasestorage.googleapis.com/v0/b/kim-var-73ce9.firebasestorage.app/o/";
const AUTHOR = "author-uid";
const VICTIM = "victim-uid";

/** A download URL for [path], shaped exactly like `getDownloadURL()`. */
function urlFor(path: string): string {
  return `${BUCKET}${encodeURIComponent(path)}?alt=media&token=6f1b0b2e-0000-4000-8000-abcdefabcdef`;
}

describe("storagePathFromDownloadUrl", () => {
  test("decodes a real download URL", () => {
    assert.equal(
      storagePathFromDownloadUrl(urlFor("posts/author-uid/1756630000000000.jpg")),
      "posts/author-uid/1756630000000000.jpg",
    );
  });

  test("works without a query string", () => {
    assert.equal(storagePathFromDownloadUrl(`${BUCKET}posts%2Fa%2Fb.jpg`), "posts/a/b.jpg");
  });

  test("returns null — NOT the input — for a string with no /o/ marker", () => {
    // The old implementation returned `url` itself here, which meant a
    // malformed value was passed to `bucket.file()` as if it were a
    // path. Failing open in the deletion direction is the one failure
    // mode this module exists to remove.
    assert.equal(storagePathFromDownloadUrl("https://example.com/evil.jpg"), null);
  });

  test("returns null for non-strings, empty strings and empty paths", () => {
    for (const bad of [undefined, null, 42, {}, "", `${BUCKET}`, `${BUCKET}?alt=media`]) {
      assert.equal(storagePathFromDownloadUrl(bad), null, `expected null for ${JSON.stringify(bad)}`);
    }
  });

  test("returns null for malformed percent-encoding instead of throwing", () => {
    // `decodeURIComponent('%')` throws URIError; an exception here
    // would propagate out of a delete path that must not crash.
    assert.equal(storagePathFromDownloadUrl(`${BUCKET}%`), null);
  });
});

describe("confinedStoragePath — the vector this closes", () => {
  const prefix = postMediaPrefix(AUTHOR);

  test("REFUSES another user's KYC evidence", () => {
    // The exact payload from the audit: bucket prefix is legitimate
    // (so `firestore.rules`' `isOwnStorageUrl` accepts the post), the
    // path is not.
    const url = urlFor(`identity_verifications/${VICTIM}/req-1/front.jpg`);
    assert.equal(confinedStoragePath(url, prefix), null);
  });

  test("REFUSES another user's post media", () => {
    assert.equal(confinedStoragePath(urlFor(`posts/${VICTIM}/1756630000000000.jpg`), prefix), null);
  });

  test("REFUSES a uid that merely starts with the author's", () => {
    // Why `postMediaPrefix` keeps its trailing slash.
    assert.equal(confinedStoragePath(urlFor(`posts/${AUTHOR}-extra/x.jpg`), prefix), null);
  });

  test("REFUSES every other owner-scoped folder", () => {
    for (const path of [
      `profile_photos/${VICTIM}/profile.jpg`,
      `stories/${VICTIM}/1.jpg`,
      `venue_photos/${VICTIM}/v1.jpg`,
      `offer_photos/${VICTIM}/o1.jpg`,
      `pinbox_photos/${VICTIM}/p1.jpg`,
      `event_covers/${VICTIM}/e1.jpg`,
      `chat_photos/a_b/a/m1.jpg`,
    ]) {
      assert.equal(confinedStoragePath(urlFor(path), prefix), null, `expected refusal for ${path}`);
    }
  });

  test("REFUSES traversal and empty segments rather than normalizing them", () => {
    for (const path of [
      `posts/${AUTHOR}/../../identity_verifications/${VICTIM}/req-1/front.jpg`,
      `posts/${AUTHOR}/..`,
      `posts/${AUTHOR}//x.jpg`,
    ]) {
      assert.equal(confinedStoragePath(urlFor(path), prefix), null, `expected refusal for ${path}`);
    }
  });

  test("REFUSES the folder itself, with no file name", () => {
    assert.equal(confinedStoragePath(urlFor(`posts/${AUTHOR}/`), prefix), null);
  });

  test("REFUSES a non-URL and a foreign bucket", () => {
    assert.equal(confinedStoragePath("posts/author-uid/x.jpg", prefix), null);
    assert.equal(confinedStoragePath(undefined, prefix), null);
  });

  test("ALLOWS the author's own media — the legitimate case still works", () => {
    const path = `posts/${AUTHOR}/1756630000000000.jpg`;
    assert.equal(confinedStoragePath(urlFor(path), prefix), path);
  });

  test("ALLOWS the author's own video thumbnail (same folder, same prefix)", () => {
    // `_uploadVideoThumbnail` reuses `PostRepository.uploadMedia`, so
    // `thumbnailUrl` lands under the same `posts/{uid}/` folder — one
    // prefix covers both fields.
    const path = `posts/${AUTHOR}/1756630000000001.jpg`;
    assert.equal(confinedStoragePath(urlFor(path), prefix), path);
  });

  test("a prefix without a trailing slash is a programming error, not a silent pass", () => {
    assert.throws(() => confinedStoragePath(urlFor("posts/author-uid/x.jpg"), `posts/${AUTHOR}`), /trailing|end with/i);
  });
});
