import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/offers/domain/entities/offer.dart';
import 'package:peakpin/features/venues/domain/entities/venue.dart';

/// Dart-side only — `offerPlacementFeeForCategory` is a client-side
/// estimate (see its own doc comment); the real charge, and the
/// `venueSubscriptionFeeByCategory`/`OFFER_ONLY_VENUE_CATEGORIES`
/// server-side maps in functions/src/index.ts, aren't reachable from
/// `flutter test` and aren't covered here — verified by TypeScript
/// compilation (`npm run build` in functions/) instead, and by the
/// spot-check already done during research that the two tables agree.
void main() {
  test('wineHouse — 30 AZN subscription tier → 7 AZN offer placement fee', () {
    expect(offerPlacementFeeForCategory(VenueCategory.wineHouse), 7.0);
  });

  test('homeServices — 20 AZN subscription tier → 4 AZN offer placement fee', () {
    expect(offerPlacementFeeForCategory(VenueCategory.homeServices), 4.0);
  });

  test('realEstate — 25 AZN subscription tier → 5 AZN offer placement fee', () {
    expect(offerPlacementFeeForCategory(VenueCategory.realEstate), 5.0);
  });
}
