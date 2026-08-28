import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/constants/category_capabilities.dart';
import 'package:peakpin/features/venues/domain/entities/venue.dart';

void main() {
  group('offer-only categories', () {
    for (final category in [VenueCategory.wineHouse, VenueCategory.homeServices, VenueCategory.realEstate]) {
      test('${category.name} can create offers but nothing else', () {
        final capabilities = category.capabilities;
        expect(capabilities.canCreateOffers, true);
        expect(capabilities.canCreateEvents, false);
        expect(capabilities.canUsePinBox, false);
        expect(capabilities.canUseWaitlist, false);
        expect(capabilities.canUseQueue, false);
      });
    }
  });

  group('existing categories keep every capability (no behavior change)', () {
    for (final category in [VenueCategory.restaurant, VenueCategory.pub, VenueCategory.other]) {
      test('${category.name} has every capability enabled', () {
        final capabilities = category.capabilities;
        expect(capabilities.canCreateOffers, true);
        expect(capabilities.canCreateEvents, true);
        expect(capabilities.canUsePinBox, true);
        expect(capabilities.canUseWaitlist, true);
        expect(capabilities.canUseQueue, true);
      });
    }
  });

  test('kCategoryCapabilities only lists the 3 offer-only categories — nothing else restricted by accident', () {
    expect(kCategoryCapabilities.keys.toSet(), {
      VenueCategory.wineHouse,
      VenueCategory.homeServices,
      VenueCategory.realEstate,
    });
  });

  test('a category absent from the map fails OPEN (every capability true), not closed', () {
    // Every VenueCategory not explicitly listed in kCategoryCapabilities
    // exercises the same `?? const CategoryCapabilities()` fallback a
    // hypothetical future category would — this loop is the practical
    // proxy for that, since VenueCategory is a fixed enum.
    for (final category in VenueCategory.values) {
      if (kCategoryCapabilities.containsKey(category)) continue;
      final capabilities = category.capabilities;
      expect(capabilities.canCreateOffers, true, reason: '${category.name} should fail open');
      expect(capabilities.canCreateEvents, true, reason: '${category.name} should fail open');
      expect(capabilities.canUsePinBox, true, reason: '${category.name} should fail open');
      expect(capabilities.canUseWaitlist, true, reason: '${category.name} should fail open');
      expect(capabilities.canUseQueue, true, reason: '${category.name} should fail open');
    }
  });
}
