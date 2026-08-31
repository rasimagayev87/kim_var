/**
 * Storage paths for listing and story media, derived from
 * server-known values only.
 *
 * ── Why derivation, not parsing ────────────────────────────────────
 *
 * The alternative is reading the `mediaUrl`/`coverImageUrl` field off
 * the document and turning it into a path. That is what
 * `deleteStorageObjectByUrl` did (P0 / C-1) and what the admin panel's
 * post deletion still did until the 2026-08-31 audit: a client-written
 * string handed to `bucket.file().delete()` on the Admin SDK, which
 * meant any object in the bucket could be addressed by writing the
 * right URL into your own document.
 *
 * Every path below is built from an owner uid and a document id, both
 * of which the server holds. No client string reaches Storage.
 *
 * ── Why these are safe to derive ───────────────────────────────────
 *
 * Unlike chat media (`chat-media.ts`) and post media (which the admin
 * panel has to CONFINE rather than derive, because its filename is an
 * upload timestamp), these four are uploaded to a deterministic path
 * built from the same two values:
 *
 *   venue_photos/{ownerUid}/{venueId}.jpg    firebase_venue_remote_datasource.dart:150
 *   offer_photos/{ownerUid}/{offerId}.jpg    firebase_offer_remote_datasource.dart:124
 *   pinbox_photos/{ownerUid}/{pinboxId}.jpg  firebase_pinbox_remote_datasource.dart:76
 *   event_covers/{ownerUid}/{eventId}.jpg    firebase_venue_event_repository.dart:70
 *
 * Stories are the one variable case — image or video — so the caller
 * passes the media type.
 *
 * No SDK imports, so `tests/rules/media-paths.test.ts` can assert the
 * shapes directly.
 */

/** A `/` in either id would let a crafted value climb out of the
 * intended prefix. Neither can contain one — Firestore document ids
 * forbid `/`, and uids are alphanumeric — so this is a structural
 * assertion rather than a live filter, kept because the whole point of
 * this module is that its output needs no re-checking by the caller. */
function isSafeSegment(value: unknown): value is string {
  return typeof value === "string" && value !== "" && !value.includes("/");
}

function ownedJpegPath(folder: string, ownerUid: unknown, docId: unknown): string | null {
  if (!isSafeSegment(ownerUid) || !isSafeSegment(docId)) return null;
  return `${folder}/${ownerUid}/${docId}.jpg`;
}

export function venuePhotoPath(ownerUid: unknown, venueId: unknown): string | null {
  return ownedJpegPath("venue_photos", ownerUid, venueId);
}

export function offerPhotoPath(ownerUid: unknown, offerId: unknown): string | null {
  return ownedJpegPath("offer_photos", ownerUid, offerId);
}

export function pinboxPhotoPath(ownerUid: unknown, pinboxId: unknown): string | null {
  return ownedJpegPath("pinbox_photos", ownerUid, pinboxId);
}

export function eventCoverPath(ownerUid: unknown, eventId: unknown): string | null {
  return ownedJpegPath("event_covers", ownerUid, eventId);
}

/**
 * `stories/{creatorId}/{storyId}.{jpg|mp4}` — the only one of these
 * whose extension varies, so `mediaType` decides it.
 *
 * Mirrors `FirebaseStoryRepository.createStory`'s own
 * `'stories/$creatorId/${ref.id}.$extension'`. An unrecognised type
 * returns `null` so nothing is deleted, rather than guessing an
 * extension and deleting nothing while reporting success.
 */
export function storyMediaPath(creatorId: unknown, storyId: unknown, mediaType: unknown): string | null {
  if (!isSafeSegment(creatorId) || !isSafeSegment(storyId)) return null;
  const extension = mediaType === "video" ? "mp4" : mediaType === "image" ? "jpg" : null;
  if (extension === null) return null;
  return `stories/${creatorId}/${storyId}.${extension}`;
}
