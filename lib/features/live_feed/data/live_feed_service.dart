import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../domain/entities/live_feed_item.dart';

/// A venue found by [LiveFeedService.fetchVenueSnapshots] — just enough
/// to derive "Boş yer var" cards for free and to drive the separate,
/// slower [LiveFeedService.fetchAudienceItems] pass. Public (not a
/// private class) purely so `LiveFeedController` can hold onto the
/// list between its two independent poll cycles without re-running
/// the geo-query every time the audience timer fires — see
/// `live_feed_providers.dart`'s doc comment for why those two cycles
/// run on different cadences.
class LiveFeedVenueSnapshot {
  final String id;
  final String name;
  final String category;
  final double distanceMeters;
  final int? availableSeats;
  final DateTime? seatsUpdatedAt;

  const LiveFeedVenueSnapshot({
    required this.id,
    required this.name,
    required this.category,
    required this.distanceMeters,
    required this.availableSeats,
    required this.seatsUpdatedAt,
  });
}

/// Read-only aggregator over collections owned by other, untouched
/// modules (`venues`, `offers`, `venueEvents`, a venue's own
/// `activeCheckins` subcollection, `config/eventCategories`,
/// `config/waitlistCategories`) — see the "Canlı" feature's own doc
/// comment at the top of `live_feed_providers.dart` for why this
/// deliberately does its own direct Firestore reads instead of calling
/// into `VenueRepository`/`OfferRepository`/`VenueEventRepository`:
/// this whole module needs to stay deletable without touching a single
/// line in Venues/Offers/Events/Waitlist, and doing its own reads
/// (using the exact same field names/conventions those modules already
/// use — 'position' geo field, 'status', 'category', etc. — just never
/// importing their code) is what makes that true.
///
/// Every fetch here is one-shot (`.get()`), never `.snapshots()` — see
/// `LiveFeedController`'s doc comment for why (polling, not realtime
/// listeners, is the explicit design for this tab). Split into several
/// public methods rather than one combined `fetch()` specifically so
/// [LiveFeedController] can run [fetchAudienceItems] (the expensive
/// part — up to 30 extra reads) on its own slower cadence, independent
/// of everything else.
class LiveFeedService {
  LiveFeedService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _geoField = 'position';

  /// Matches `_checkinExpiry` in `firebase_venue_remote_datasource.dart`
  /// — independently declared (not imported) per this module's
  /// isolation goal, but intentionally kept equal so "canlı" here means
  /// the same thing it does on a venue's own profile page.
  static const _activeCheckinWindow = Duration(hours: 2);

  /// How many nearby venues to check `activeCheckins` for, at most —
  /// each check is its own read, so this bounds the "Ətrafınızda"
  /// section's cost regardless of how many venues a wide radius turns up.
  static const _audienceCheckLimit = 30;

  Future<List<LiveFeedVenueSnapshot>> fetchVenueSnapshots({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_firestore.collection('venues'));
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: _geoField,
      geopointFrom: (data) => data[_geoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) => query.where('status', isEqualTo: 'approved'),
      strictMode: true,
    );

    return results.map((r) {
      final data = r.documentSnapshot.data()!;
      return LiveFeedVenueSnapshot(
        id: r.documentSnapshot.id,
        name: (data['name'] as String?) ?? '',
        category: (data['category'] as String?) ?? '',
        distanceMeters: r.distanceFromCenterInKm * 1000,
        availableSeats: data['availableSeats'] as int?,
        seatsUpdatedAt: (data['seatsUpdatedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  /// "Ətrafınızda" — a venue with at least one `activeCheckins` entry
  /// inside [_activeCheckinWindow], same window/subcollection the
  /// venue's own live "hazırda N nəfər" counter reads (just as a
  /// one-shot count here instead of that counter's realtime listener).
  /// Capped at [_audienceCheckLimit] nearest venues so a wide radius
  /// can't turn this into dozens of reads on every poll — and, per the
  /// controller's own slower cadence for this specific method, doesn't
  /// run nearly as often as the rest of the tab to begin with.
  Future<List<LiveFeedItem>> fetchAudienceItems(List<LiveFeedVenueSnapshot> venues) async {
    final candidates = [...venues]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(_activeCheckinWindow));

    final items = <LiveFeedItem>[];
    for (final venue in candidates.take(_audienceCheckLimit)) {
      final snap = await _firestore
          .collection('venues')
          .doc(venue.id)
          .collection('activeCheckins')
          .where('createdAt', isGreaterThan: cutoff)
          .get();
      final count = snap.docs.length;
      if (count == 0) continue;

      items.add(LiveFeedItem(
        id: 'audience_${venue.id}',
        type: LiveFeedType.audience,
        venueId: venue.id,
        targetId: venue.id,
        targetType: 'venue',
        title: venue.name,
        subtitle: '$count nəfər burada',
        distanceMeters: venue.distanceMeters,
        timestamp: DateTime.now(),
      ));
    }
    return items;
  }

  /// "Boş yer var" — venues whose owner has turned the seat counter on
  /// and it currently reads above zero. No extra fetch needed: this is
  /// a free derivation from [fetchVenueSnapshots]'s own result.
  List<LiveFeedItem> seatAvailableItemsFrom(List<LiveFeedVenueSnapshot> venues) {
    return venues.where((v) => (v.availableSeats ?? 0) > 0).map((venue) {
      return LiveFeedItem(
        id: 'seat_${venue.id}',
        type: LiveFeedType.seatAvailable,
        venueId: venue.id,
        targetId: venue.id,
        targetType: 'venue',
        title: venue.name,
        subtitle: '${venue.availableSeats} boş yer var',
        distanceMeters: venue.distanceMeters,
        timestamp: venue.seatsUpdatedAt ?? DateTime.now(),
      );
    }).toList();
  }

  /// "Bu axşam" — `venueEvents` docs currently `live`, or `upcoming`
  /// and starting within the next 24h. Filtered against
  /// [categoryByVenueId]/[eventCategories] as defense-in-depth (an
  /// event can only ever be CREATED by an eligible-category venue —
  /// see `venueEvents`' own create rule — so this should rarely
  /// exclude anything; it exists for the same "category changed after
  /// the fact" edge case `VenueWaitlistScreen`'s own gate handles). A
  /// venue missing from [categoryByVenueId] (its own geo-query somehow
  /// didn't turn it up) fails OPEN — shown, not hidden — since this is
  /// a display nicety, not a security boundary.
  Future<List<LiveFeedItem>> fetchEventItems({
    required double lat,
    required double lng,
    required double radiusKm,
    required Map<String, String> categoryByVenueId,
  }) async {
    final eventCategories = await _configCategories('eventCategories');
    final now = DateTime.now();

    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_firestore.collection('venueEvents'));
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: _geoField,
      geopointFrom: (data) => data[_geoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) => query.where('status', whereIn: ['upcoming', 'live']),
      strictMode: true,
    );

    final items = <LiveFeedItem>[];
    for (final r in results) {
      final data = r.documentSnapshot.data()!;
      final venueId = data['venueId'] as String? ?? '';
      final category = categoryByVenueId[venueId];
      if (category != null && !eventCategories.contains(category)) continue;

      final status = data['status'] as String?;
      final startAt = (data['startAt'] as Timestamp?)?.toDate();
      if (startAt == null) continue;
      // A `live` event is always shown regardless of how long ago it
      // started; an `upcoming` one only counts as "fresh" once it's
      // within the confirmed 24h horizon — this is "Bu axşam", not
      // "sometime next week".
      if (status == 'upcoming' && startAt.isAfter(now.add(const Duration(hours: 24)))) continue;

      items.add(LiveFeedItem(
        id: 'event_${r.documentSnapshot.id}',
        type: LiveFeedType.event,
        venueId: venueId,
        targetId: r.documentSnapshot.id,
        targetType: 'event',
        title: (data['title'] as String?) ?? '',
        subtitle: (data['venueName'] as String?) ?? '',
        distanceMeters: r.distanceFromCenterInKm * 1000,
        timestamp: startAt,
      ));
    }
    return items;
  }

  /// "Yeni təkliflər" + "Doğum günü" both come from the same
  /// `offers` geo-query — split by `offerType` afterward. Birthday
  /// offers are filtered to `targetUserIds` containing [myUid],
  /// mirroring `nearbyOffersProvider`'s own identical privacy rule
  /// (a birthday offer is never "for everyone", even within radius).
  Future<List<LiveFeedItem>> fetchOfferAndBirthdayItems({
    required double lat,
    required double lng,
    required double radiusKm,
    required String? myUid,
    required Duration freshWindow,
  }) async {
    final freshCutoff = DateTime.now().subtract(freshWindow);

    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_firestore.collection('offers'));
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: _geoField,
      geopointFrom: (data) => data[_geoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) => query.where('status', isEqualTo: 'approved').where('happyHourActive', isEqualTo: true),
      strictMode: true,
    );

    final items = <LiveFeedItem>[];
    for (final r in results) {
      final data = r.documentSnapshot.data()!;
      final offerType = data['offerType'] as String?;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) continue;
      final title = (data['title'] as String?) ?? '';
      final venueId = (data['venueId'] as String?) ?? '';
      final venueName = (data['venueName'] as String?) ?? '';
      final distanceMeters = r.distanceFromCenterInKm * 1000;

      if (offerType == 'birthday') {
        final targetUserIds = (data['targetUserIds'] as List?)?.cast<String>() ?? const [];
        if (myUid == null || !targetUserIds.contains(myUid)) continue;
        items.add(LiveFeedItem(
          id: 'birthday_${r.documentSnapshot.id}',
          type: LiveFeedType.birthday,
          venueId: venueId,
          targetId: r.documentSnapshot.id,
          targetType: 'offer',
          title: title,
          subtitle: venueName,
          distanceMeters: distanceMeters,
          timestamp: createdAt,
        ));
        continue;
      }

      if (createdAt.isBefore(freshCutoff)) continue;
      items.add(LiveFeedItem(
        id: 'offer_${r.documentSnapshot.id}',
        type: LiveFeedType.offer,
        venueId: venueId,
        targetId: r.documentSnapshot.id,
        targetType: 'offer',
        title: title,
        subtitle: venueName,
        distanceMeters: distanceMeters,
        timestamp: createdAt,
      ));
    }
    return items;
  }

  Future<Set<String>> _configCategories(String docId) async {
    final snap = await _firestore.collection('config').doc(docId).get();
    final raw = (snap.data()?['enabledCategories'] as List?)?.cast<String>() ?? const [];
    return raw.toSet();
  }
}
