/**
 * E.164 normalisation for the one phone number this app stores.
 *
 * The client is where the malformed values came from (see
 * `_applyDialCodeForCountry` in onboarding_screen.dart — picking a
 * country after typing a full international number stacked a second
 * dial code, producing `+994+994502749898`), and that is fixed there.
 * This exists because fixing it there is not enough: the phone number
 * is written exactly once, at onboarding, and there is no edit screen,
 * so a value written by an older build is permanent. Every install
 * currently in the wild still has the old behaviour, and `submitVenue`
 * and `joinWaitlist` take phone input from the same kind of field.
 *
 * Deliberately narrow. This is not a phone-validation library and does
 * not know which country codes are real or how long a local number
 * should be — it enforces the shape the schema promises (`E.164`, one
 * leading `+`, digits only) and rejects what cannot be repaired without
 * guessing. Guessing is how the original bug happened.
 */

/** ITU-T E.164: at most 15 digits after the `+`. Minimum of 8 is a
 * pragmatic floor — shorter than any mobile number in the markets this
 * app serves, and low enough not to reject an unusual one. */
const E164_MIN_DIGITS = 8;
const E164_MAX_DIGITS = 15;

export class InvalidPhoneNumberError extends Error {
  constructor(readonly reason: string) {
    super(`invalid-phone-number: ${reason}`);
  }
}

/**
 * Returns [raw] as strict E.164, or throws [InvalidPhoneNumberError].
 *
 * Repairs exactly two things, both of which are formatting rather than
 * content: whitespace/separators a human typed, and a duplicated
 * leading dial code where the SECOND copy is a prefix of what follows
 * (`+994+994502749898` → `+994502749898`). Anything else — two
 * different dial codes, letters, a plausible-looking but wrong length —
 * is rejected rather than silently altered, because "fix it up as best
 * we can" is what turned one number into an unusable one in the first
 * place.
 */
export function normalizePhoneNumber(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) throw new InvalidPhoneNumberError("empty");

  // Separators humans type: spaces, hyphens, parentheses, dots.
  const cleaned = trimmed.replace(/[\s\-().]/g, "");

  // Collapse a repeated leading `+NNN+NNN…` when both copies match.
  const doubled = cleaned.match(/^(\+\d{1,4})\1(\d+)$/);
  const candidate = doubled ? `${doubled[1]}${doubled[2]}` : cleaned;

  if (!candidate.startsWith("+")) throw new InvalidPhoneNumberError("missing-plus");
  const digits = candidate.slice(1);
  if (!/^\d+$/.test(digits)) throw new InvalidPhoneNumberError("non-digit");
  if (digits.length < E164_MIN_DIGITS) throw new InvalidPhoneNumberError("too-short");
  if (digits.length > E164_MAX_DIGITS) throw new InvalidPhoneNumberError("too-long");

  return `+${digits}`;
}

/** True when [raw] is already valid E.164 and needs no repair — used by
 * the read-only audit script to count malformed stored values. */
export function isNormalizedPhoneNumber(raw: unknown): boolean {
  if (typeof raw !== "string") return false;
  try {
    return normalizePhoneNumber(raw) === raw;
  } catch {
    return false;
  }
}
