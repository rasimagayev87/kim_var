/**
 * Admin-panel copy of `functions/src/venue-fees.ts`.
 *
 * The two are separate Node projects with no shared package. Held in
 * sync by `tests/rules/venue-fees.test.ts`, which imports BOTH and
 * fails on any disagreement — the same arrangement as
 * `chat-media-path.ts`. Edit one, edit the other, and let the test
 * catch you if you don't.
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
