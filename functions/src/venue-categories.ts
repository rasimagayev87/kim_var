/**
 * Which venue categories may use which feature.
 *
 * ── The gap this closes ────────────────────────────────────────────
 *
 * Four features are restricted to specific categories. Until now the
 * restriction lived only where a user could see it:
 *
 *   PinBox    `kPinboxEligibleVenueCategories` (venue.dart)  — UI only
 *   Events    `config/eventCategories`                        — UI only
 *   Waitlist  `config/waitlistCategories`                     — UI only
 *   Birthday  `kBirthdayEligibleVenueCategories` (venue.dart) — UI only
 *
 * The server checked something different and much weaker: a THREE-item
 * blacklist (`isOfferOnlyCategory` in firestore.rules,
 * `OFFER_ONLY_VENUE_CATEGORIES` here) covering only wineHouse,
 * homeServices and realEstate. Since PinBox creation is a direct client
 * write, a hotel or a gym owner who skipped the UI could create one and
 * the rules allowed it. "Hiding it in the UI is not authorization" —
 * the same class as every other finding in this pass.
 *
 * These lists are ALLOWLISTS and replace the blacklist at each call
 * site rather than joining it. A blacklist answers "is this one of the
 * three we forbid"; the product question is "is this one of the six we
 * permit", and those are different questions the moment a category is
 * added.
 *
 * ── Three copies, held together by a test ──────────────────────────
 *
 * Each list exists three times: here (callables), in `firestore.rules`
 * (direct client writes), and in `venue.dart` (what the UI offers).
 * Rules cannot import TypeScript and Dart cannot import either, so the
 * duplication is structural — the same arrangement as
 * `OFFER_ONLY_VENUE_CATEGORIES`, `venueSubscriptionFeeByCategory` and
 * `notification-categories.ts`.
 *
 * `tests/rules/venue-categories.test.ts` parses all three sources and
 * fails if any pair disagrees. That test is the only thing keeping them
 * honest; do not add a fourth copy without adding it there too.
 *
 * ── Why not `config/*` in Firestore ────────────────────────────────
 *
 * Events and Waitlist previously read their lists from
 * `config/eventCategories` / `config/waitlistCategories`, set by a
 * script. That looked more flexible and was in practice a second source
 * of truth that no server code consulted: `joinWaitlist` enforced only
 * the blacklist, and `firestore.rules` hardcoded the waitlist ten
 * anyway (for the `reviews` gate). Three places, one of them invisible
 * in the repository, none of them authoritative.
 *
 * The config documents stay in Firestore — deleting production data is
 * not this change's business — but nothing reads them any more, and
 * `scripts/deprecate-category-configs.ts` marks them so that whoever
 * opens the Console next is not misled by them.
 */

/** Events — "Tədbir yarat". */
export const EVENT_ELIGIBLE_CATEGORIES: readonly string[] = [
  "restaurant",
  "pub",
  "fastFood",
  "cinema",
  "nightClub",
  "kidsEntertainment",
  "independentArtist",
];

/** PinBox — surplus/limited-stock boxes. Perishable, quick-turnover
 * goods only, locked in by the product owner at PinBox's spec. */
export const PINBOX_ELIGIBLE_CATEGORIES: readonly string[] = [
  "restaurant",
  "coffeeShop",
  "fastFood",
  "sweetsShop",
  "perfumeryCosmetics",
  "supermarket",
];

/** Walk-in queue ("Növbə"). Matches the list `firestore.rules` already
 * hardcoded for the `reviews` verified-visit gate — a review can only
 * exist behind a `seated` waitlist entry, so the two must agree. */
export const WAITLIST_ELIGIBLE_CATEGORIES: readonly string[] = [
  "restaurant",
  "pub",
  "fastFood",
  "coffeeShop",
  "teaHouse",
  "karaoke",
  "sweetsShop",
  "gameHall",
  "spa",
  "carWash",
];

/**
 * Venues that may send birthday campaigns.
 *
 * `hotel` and `kidsEntertainment` were REMOVED here (15 → 13) on
 * product direction. Neither had a server check before, so nothing
 * changes for them retroactively — a venue in either category that
 * already has `birthdayNotificationsEnabled: true` simply stops being
 * picked up by `computeBirthdayMatches`.
 */
export const BIRTHDAY_ELIGIBLE_CATEGORIES: readonly string[] = [
  "restaurant",
  "pub",
  "coffeeShop",
  "sweetsShop",
  "fastFood",
  "cinema",
  "karaoke",
  "nightClub",
  "spa",
  "cosmetology",
  "photoStudio",
  "beautySalon",
  "perfumeryCosmetics",
];

export function isEventCategory(category: unknown): boolean {
  return typeof category === "string" && EVENT_ELIGIBLE_CATEGORIES.includes(category);
}

export function isPinBoxCategory(category: unknown): boolean {
  return typeof category === "string" && PINBOX_ELIGIBLE_CATEGORIES.includes(category);
}

export function isWaitlistCategory(category: unknown): boolean {
  return typeof category === "string" && WAITLIST_ELIGIBLE_CATEGORIES.includes(category);
}

export function isBirthdayCategory(category: unknown): boolean {
  return typeof category === "string" && BIRTHDAY_ELIGIBLE_CATEGORIES.includes(category);
}
