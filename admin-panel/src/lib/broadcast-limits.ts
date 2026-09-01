/**
 * Broadcast size limits.
 *
 * A separate module because `lib/actions/broadcast.ts` carries
 * `"use server"`, and such a file may export ONLY async functions —
 * a `export const` there fails the Turbopack build (though it passes
 * `tsc --noEmit`, which is why this was caught by the deploy and not
 * by the type check).
 *
 * Living here also lets the form show the same numbers it validates
 * against, instead of hardcoding them twice.
 */

/** Matches the notification copy limits every other path already has —
 * chat text is capped at 2000 in `firestore.rules`, a listing title at
 * 120. A broadcast writes one document per recipient, so an unbounded
 * body is multiplied by the audience. */
export const BROADCAST_TITLE_MAX = 120;
export const BROADCAST_BODY_MAX = 500;

/**
 * A single broadcast may not exceed this many recipients.
 *
 * A send cannot be undone: the documents are written and the pushes
 * are delivered. "All users" is exactly the shape of mistake that has
 * no recovery, and the number only grows. Past this the send is
 * REFUSED rather than truncated — reaching an arbitrary subset is
 * worse than reaching nobody, because it cannot be completed and
 * nobody can say who got it.
 *
 * Raising it should come with a second confirmation in the UI, not a
 * bigger constant.
 */
export const BROADCAST_AUDIENCE_MAX = 5000;
