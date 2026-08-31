/**
 * Venue subscription pricing — the AZN-per-month a venue is charged,
 * by category, plus the categories that may only run offers.
 *
 * Extracted from `index.ts` so the admin panel can show the same
 * numbers without a fourth hand-maintained copy. There are already
 * three: this table, `_venueListingFeeFor` in
 * `lib/features/venues/data/repositories/firebase_venue_repository.dart`,
 * and `isOfferOnlyCategory` in `firestore.rules`. The Dart and Rules
 * copies are unavoidable — neither can import TypeScript. The admin
 * panel's copy is NOT unavoidable in principle, but the two are
 * separate Node projects with no shared package, so it is duplicated
 * and held together by a parity test (`tests/rules/venue-fees.test.ts`)
 * that fails the moment the tables disagree — the same arrangement
 * `chat-media.ts` and `phone.ts` already use.
 *
 * Exhaustive on purpose: a `switch` with a default would silently
 * charge 0 AZN for a category added on the Flutter side and forgotten
 * here, so this is a plain lookup and `renewVenueSubscriptions` treats
 * a missing entry as a bug to log rather than a free month.
 */
export const venueSubscriptionFeeByCategory: Record<string, number> = {
  restaurant: 30, pub: 30, coffeeShop: 25, fastFood: 25, teaHouse: 15, sweetsShop: 20,
  hotel: 30, motel: 20, cinema: 30, karaoke: 30, gameHall: 30, nightClub: 30,
  fitness: 30, gym: 30, spa: 30, footballField: 25, clinic: 30, beautySalon: 30,
  barbershop: 20, cosmetology: 30, tattoo: 20, photoStudio: 20, kidsEntertainment: 30,
  pharmacyOptics: 30, dentalClinic: 30, perfumeryCosmetics: 25, carWash: 20, carRepair: 20,
  supermarket: 30, bookstoreStationery: 20, petStore: 20, tailor: 15, dryCleaning: 25,
  applianceRepair: 20, tutoringCenter: 25,
  // Offer-only categories — see OFFER_ONLY_VENUE_CATEGORIES below and
  // lib/core/constants/category_capabilities.dart on the Dart side.
  wineHouse: 30, homeServices: 20, realEstate: 25,
  independentArtist: 30, other: 25,
};

/** Categories restricted to offers-only — cannot create Events, PinBox
 * listings, or waitlist entries. Enforced here (`joinWaitlist`) and
 * mirrored as literal strings in firestore.rules' `isOfferOnlyCategory`
 * (Rules can't import this constant — see that function's own comment
 * for the duplication-risk note). Mirrors
 * `lib/core/constants/category_capabilities.dart`'s `kCategoryCapabilities`
 * on the Dart/client side.
 */
export const OFFER_ONLY_VENUE_CATEGORIES = ["wineHouse", "homeServices", "realEstate"];

/**
 * The distinct monthly prices, descending. The admin panel groups
 * categories into these tiers so a "subscriptions by category"
 * breakdown costs one aggregate query per tier instead of one per
 * category — four reads rather than thirty-six, and constant as
 * categories are added.
 */
export const SUBSCRIPTION_FEE_TIERS: readonly number[] = Array.from(
  new Set(Object.values(venueSubscriptionFeeByCategory)),
).sort((a, b) => b - a);

/** Every category charged [fee] AZN per month. */
export function categoriesAtFee(fee: number): string[] {
  return Object.entries(venueSubscriptionFeeByCategory)
    .filter(([, amount]) => amount === fee)
    .map(([category]) => category);
}

/**
 * How many campaigns a venue may publish for free each subscription
 * period, by its monthly tier.
 *
 * ── The change this encodes ────────────────────────────────────────
 *
 * Every campaign used to cost a placement fee on top of the monthly
 * subscription (`OFFER_PLACEMENT_FEE_BY_SUBSCRIPTION_TIER` in
 * index.ts). Paying twice for the same thing made the subscription
 * look like it bought nothing, and the fee sat between an owner and
 * the one action the whole product depends on them taking. The tier
 * now includes a quota; the placement fee remains, but only once that
 * quota is spent.
 *
 * Keyed off the SUBSCRIPTION TIER, never off the category, exactly like
 * the placement fee it sits beside — so a category's quota is always a
 * function of what it pays, and a new category picks up the right quota
 * by picking up the right price. The alternative, a second 39-entry
 * category table, is a second thing to forget.
 *
 * `tests/rules/venue-fees.test.ts` asserts these keys are EXACTLY
 * `SUBSCRIPTION_FEE_TIERS`. A fifth price added to the table above
 * without a quota here would otherwise mean `undefined` — which reads
 * as "no free campaigns" and would quietly start charging a whole tier
 * of venues for something they were promised.
 */
export const FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER: Record<number, number> = { 15: 3, 20: 5, 25: 8, 30: 10 };

/** The period's free-campaign allowance for [category], or `undefined`
 * if the category has no subscription tier at all (a bug — see
 * `venueSubscriptionFeeByCategory`'s own doc comment). */
export function freeCampaignQuotaForCategory(category: string): number | undefined {
  const tier = venueSubscriptionFeeByCategory[category];
  if (tier === undefined) return undefined;
  return FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER[tier];
}
