import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/features/venues/domain/entities/venue.dart';

/// `FirebaseVenueRepository` itself talks to a real
/// `VenueRemoteDatasource` (Firestore `QuerySnapshot`s aren't
/// constructable outside the SDK without a package like
/// `fake_cloud_firestore`, not yet a dev dependency here — a real gap,
/// flagged in the handoff report same as the Rules-emulator one).
/// What's tested here instead, with zero Firestore test harness
/// needed, is the exact resilience PATTERN the repository's `_safeVenue`
/// + `.map(...).whereType<Venue>()` call sites apply: `Venue.fromFirestore`
/// throwing on one malformed document must not take the rest of the
/// list down with it.
Venue? _safeVenue(String id, Map<String, dynamic> data) {
  try {
    return Venue.fromFirestore(id, data);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _validVenueData() => {
  'ownerId': 'owner-1',
  'name': 'Test Venue',
  'lat': 40.4,
  'lng': 49.8,
  'address': 'Test address',
  'createdAt': Timestamp.now(),
};

void main() {
  test('a single malformed document is dropped, the rest of the list survives', () {
    final docs = <String, Map<String, dynamic>>{
      'good-1': _validVenueData(),
      // Missing every required field ('name', 'lat', 'lng', 'address',
      // 'ownerId') — Venue.fromFirestore's generated fromJson throws a
      // TypeError on this, exactly the real-world "backend schema
      // changed under an old client" scenario this guards against.
      'bad-1': <String, dynamic>{},
      'good-2': _validVenueData(),
    };

    final venues = docs.entries.map((e) => _safeVenue(e.key, e.value)).whereType<Venue>().toList();

    expect(venues.length, 2);
    expect(venues.map((v) => v.name), everyElement('Test Venue'));
  });

  test('Venue.fromFirestore itself does throw on missing required fields (sanity check for the test above)', () {
    expect(() => Venue.fromFirestore('bad', <String, dynamic>{}), throwsA(anything));
  });

  test('a fully valid document parses successfully', () {
    final venue = _safeVenue('good', _validVenueData());
    expect(venue, isNotNull);
    expect(venue!.name, 'Test Venue');
  });
}
