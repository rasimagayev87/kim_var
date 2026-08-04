import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Raw Firebase I/O boundary for the venues feature — every method
/// here speaks Firestore/Storage primitives (snapshots, plain maps,
/// files), never the domain `Venue` type. Mapping between this layer
/// and `Venue` is [FirebaseVenueRepository]'s job, not this one's, so
/// this class stays swappable/testable independent of domain rules.
abstract class VenueRemoteDatasource {
  /// Client-generated document id, allocated with no network call —
  /// needed up front so the photo can be uploaded to a path keyed by
  /// the venue's eventual id before the document itself is written.
  String allocateVenueId();

  Future<void> setVenue(String venueId, Map<String, dynamic> data);

  Future<void> updateVenue(String venueId, Map<String, dynamic> data);

  Future<void> deleteVenue(String venueId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchVenue(String venueId);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchVenuesByOwner(String ownerId);

  /// GeoFlutterFire Plus query — fans out across the neighboring
  /// geohash cells and merges results internally, returning each
  /// matching doc paired with its real distance from ([lat], [lng])
  /// in kilometres, already sorted nearest-first.
  Future<List<(DocumentSnapshot<Map<String, dynamic>> doc, double distanceKm)>> queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  });

  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category});

  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category});

  /// [onProgress] fires repeatedly with a 0.0–1.0 fraction as bytes
  /// transfer. [onTaskReady] fires exactly once, synchronously before
  /// this method's Future resolves, handing the caller a cancel
  /// function — calling it aborts the in-flight upload (the returned
  /// Future then completes with an error, same as any other upload
  /// failure, so the caller's existing retry-by-resubmitting flow
  /// covers "cancel" for free).
  Future<String> uploadVenuePhoto(
    String venueId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  });

  Future<void> deleteVenuePhoto(String venueId);

  /// Realtime set of venue ids the given user has favorited —
  /// `users/{uid}/favorites` doc ids, watched live so the heart icon
  /// stays in sync across the list and profile screen without a
  /// manual refresh.
  Stream<Set<String>> watchFavoriteVenueIds(String uid);

  /// Writes/removes the `users/{uid}/favorites/{venueId}` doc and
  /// bumps `venues/{venueId}.favoriteCount` by ±1 in the same call —
  /// two separate writes (matching this app's existing non-transactional
  /// starCount/heartCount increment precedent), not a batch/transaction.
  Future<void> setFavorite({
    required String uid,
    required String venueId,
    required bool isFavorite,
  });
}
