/**
 * Identity-field change policy — the pure half of `updateProfileDetails`.
 *
 * Split out for the same reason `venue-fees.ts` and `birthday-ranking.ts`
 * were: the numbers here are product rules, they are asserted by
 * `tests/rules/profile-identity.test.ts` without booting an emulator,
 * and that test PARSES this file so the constants cannot drift away
 * from what the tests claim.
 *
 * Why any of this is server-side at all: the previous attempt expressed
 * the `nameLower` invariant as a Firestore rule
 * (`nameLower == (firstName + ' ' + lastName).trim().lower()`) and it
 * could not work. Rules' `.lower()` is ASCII-only; Dart's
 * `String.toLowerCase()` is full Unicode. Every name carrying Ə, İ, Ş,
 * Ç, Ö, Ü or Ğ — most Azerbaijani names — failed the comparison and its
 * owner was locked out of editing their own profile. Deriving the value
 * here, with Node's Unicode-correct `toLowerCase()`, is the only place
 * the invariant can actually hold.
 */

/** `users.username` may change once every 30 days. */
export const USERNAME_COOLDOWN_DAYS = 30;

/** `firstName`/`lastName` may change once every 15 days. */
export const NAME_COOLDOWN_DAYS = 15;

/**
 * `birthDate` may be corrected exactly ONCE, ever.
 *
 * Not a cooldown — a one-shot. A birth date is not a thing that
 * changes; the only legitimate edit is fixing a value typed wrong at
 * onboarding. Left freely editable it becomes an abuse vector against
 * the birthday campaigns: set today's date, collect the offers, repeat
 * tomorrow. After the one correction the user is sent to support, which
 * is a human check on exactly the case that remains (typed wrong
 * twice).
 */
export const BIRTH_DATE_CHANGES_ALLOWED = 1;

/**
 * Same shape the client's `_usernamePattern` enforces in
 * `edit_profile_screen.dart` / the register screen. ASCII-only is
 * deliberate and load-bearing, not an oversight: `usernames/{id}` doc
 * ids are the lowercased handle, and `firestore.rules` still resolves
 * one with `.lower()` for the public deep-link `get`. A non-ASCII
 * handle would lowercase differently on the two sides — the exact
 * defect this module's header describes — so handles stay ASCII and the
 * mismatch cannot arise.
 */
export const USERNAME_PATTERN = /^[a-zA-Z0-9._]{3,20}$/;

/** The single definition of `users.nameLower`. Mirrors what
 * `completeOnboarding` writes at signup and what `updateVenue` does for
 * `venues.nameLower`. `searchUsersByName` range-scans this field and
 * never `firstName`/`lastName`, so it is the account's search key. */
export function deriveNameLower(firstName: string, lastName: string): string {
  return `${firstName} ${lastName}`.trim().toLowerCase();
}

/// Separate search key for the surname.
///
/// `nameLower` is "first last", and `searchUsersByName` is a PREFIX
/// range scan over it — so it can only ever match from the first name
/// onwards. Typing a surname returned nothing at all, which is how most
/// people search for someone they know.
///
/// A second field is the smallest fix that keeps the query a range scan
/// (Firestore has no substring search, and a token array cannot do
/// prefixes). Same Unicode-correct `toLowerCase` as `nameLower` — see
/// this module's header for why that matters here.
export function deriveLastNameLower(lastName: string): string {
  return lastName.trim().toLowerCase();
}

/**
 * Whole days still to wait, or 0 when the change is allowed now.
 *
 * Rounds UP, so a message never says "0 days" while the write would
 * still be refused — the user would retry immediately and hit the same
 * wall with no explanation. `null`/`undefined` means the field has
 * never been changed and is therefore free.
 */
export function cooldownRemainingDays(
  lastChangedAtMs: number | null | undefined,
  cooldownDays: number,
  nowMs: number,
): number {
  if (lastChangedAtMs === null || lastChangedAtMs === undefined) return 0;
  const dayMs = 24 * 60 * 60 * 1000;
  const elapsed = nowMs - lastChangedAtMs;
  const remaining = cooldownDays * dayMs - elapsed;
  if (remaining <= 0) return 0;
  return Math.ceil(remaining / dayMs);
}
