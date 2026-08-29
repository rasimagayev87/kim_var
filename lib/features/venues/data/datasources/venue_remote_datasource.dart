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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchVenuesByOwner(
    String ownerId,
  );

  /// GeoFlutterFire Plus query — fans out across the neighboring
  /// geohash cells and merges results internally, returning each
  /// matching doc paired with its real distance from ([lat], [lng])
  /// in kilometres, already sorted nearest-first.
  Future<List<(DocumentSnapshot<Map<String, dynamic>> doc, double distanceKm)>>
  queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  });

  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(
    String country, {
    String? category,
  });

  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({
    required int limit,
    String? category,
  });

  /// [onProgress] fires repeatedly with a 0.0–1.0 fraction as bytes
  /// transfer. [onTaskReady] fires exactly once, synchronously before
  /// this method's Future resolves, handing the caller a cancel
  /// function — calling it aborts the in-flight upload (the returned
  /// Future then completes with an error, same as any other upload
  /// failure, so the caller's existing retry-by-resubmitting flow
  /// covers "cancel" for free).
  /// [ownerId] is now part of the Storage path itself (Düzəliş Prompt 3
  /// / K-6, `venue_photos/{ownerId}/{venueId}.jpg` — was flat
  /// `{venueId}.jpg` with no owner segment, which `storage.rules`
  /// couldn't gate on ownership at all since Storage Rules can't `get()`
  /// Firestore). Must equal the caller's own uid — `storage.rules`
  /// enforces `request.auth.uid == ownerId`, so any other value fails.
  Future<String> uploadVenuePhoto(
    String ownerId,
    String venueId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  });

  Future<void> deleteVenuePhoto(String ownerId, String venueId);

  /// Whether [uid] has liked [venueId] — a single-doc watch on
  /// `venues/{venueId}/likes/{uid}`, mirroring
  /// `PostRemoteDatasource.watchIsLikedByMe`.
  Stream<bool> watchIsLikedByMe(String venueId, String uid);

  /// Creates/deletes ONLY the `venues/{venueId}/likes/{uid}` doc —
  /// never touches `likeCount`/`rating` itself. Those are written
  /// exclusively by the `onVenueLikeCreated`/`onVenueLikeDeleted`
  /// Cloud Function triggers reacting to this same write, which is
  /// also what firestore.rules enforces (the client has no permission
  /// to set those fields directly).
  Future<void> setLiked({
    required String uid,
    required String venueId,
    required bool isLiked,
  });

  /// Live count of `venues/{venueId}/activeCheckins` docs created
  /// within the still-valid window — never includes an entry the
  /// scheduled cleanup function would already be entitled to purge,
  /// so the number on screen never overstates who's actually there.
  Stream<int> watchActiveCheckinCount(String venueId);

  /// Whether [uid] currently has an active check-in at [venueId]
  /// specifically (not just anywhere) — a single-doc watch on
  /// `venues/{venueId}/activeCheckins/{uid}`.
  Stream<bool> watchIsCheckedInHere(String venueId, String uid);

  /// Creates `venues/{venueId}/activeCheckins/{uid}` and points
  /// `users/{uid}.activeCheckinVenueId` at it. A user can only ever
  /// have one active check-in — if they were already checked in
  /// somewhere else, that old subcollection doc is deleted in the same
  /// transaction so the move is atomic (no window where the count is
  /// wrong at both venues).
  Future<void> checkIn({required String uid, required String venueId});

  /// Deletes [uid]'s current active check-in (wherever it is) and
  /// clears `users/{uid}.activeCheckinVenueId`. No-op if they don't
  /// have one.
  Future<void> checkOut({required String uid});
}
