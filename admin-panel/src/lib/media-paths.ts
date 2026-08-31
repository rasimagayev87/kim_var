/**
 * Storage paths for listing media, derived from server-known values.
 *
 * TWIN of `functions/src/media-paths.ts`, duplicated because
 * `functions/` and `admin-panel/` are separate Node projects with no
 * shared package — the same arrangement as `chat-media-path.ts` and
 * `storage-path.ts`. `tests/rules/media-paths.test.ts` imports both and
 * fails if they disagree.
 *
 * Only the paths the admin panel actually needs live here; the
 * functions copy is the fuller one.
 */

function isSafeSegment(value: unknown): value is string {
  return typeof value === "string" && value !== "" && !value.includes("/");
}

/** `event_covers/{ownerUid}/{eventId}.jpg` — matches
 * `FirebaseVenueEventRepository`'s own upload path. */
export function eventCoverPath(ownerUid: unknown, eventId: unknown): string | null {
  if (!isSafeSegment(ownerUid) || !isSafeSegment(eventId)) return null;
  return `event_covers/${ownerUid}/${eventId}.jpg`;
}
