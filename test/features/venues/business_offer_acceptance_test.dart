import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/venues/domain/business_offer_acceptance.dart';

void main() {
  test('never accepted any version (null) → needs reacceptance', () {
    expect(needsBusinessOfferReacceptance(acceptedVersion: null, currentVersion: '1.0'), true);
  });

  test('accepted version matches current version → no reacceptance needed', () {
    expect(needsBusinessOfferReacceptance(acceptedVersion: '1.0', currentVersion: '1.0'), false);
  });

  test('accepted version differs from current version → needs reacceptance', () {
    expect(needsBusinessOfferReacceptance(acceptedVersion: '1.0', currentVersion: '1.1'), true);
  });
}
