import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'venue_remote_datasource.dart';

/// Field under which GeoFlutterFire Plus stores `{geopoint, geohash}`
/// on every venue document — separate from the plain `lat`/`lng`
/// fields (still written for the domain model/display), since this
/// nested shape is what `GeoCollectionReference` requires for its
/// geohash range queries. Public so [FirebaseVenueRepository] (which
/// builds the write payload) and this datasource (which builds the
/// query) can never drift apart on the field name.
const kVenueGeoField = 'position';

class FirebaseVenueRemoteDatasource implements VenueRemoteDatasource {
  FirebaseVenueRemoteDatasource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _venues =>
      _firestore.collection('venues');

  @override
  String allocateVenueId() => _venues.doc().id;

  @override
  Future<void> setVenue(String venueId, Map<String, dynamic> data) =>
      _venues.doc(venueId).set(data);

  @override
  Future<void> updateVenue(String venueId, Map<String, dynamic> data) =>
      _venues.doc(venueId).update(data);

  @override
  Future<void> deleteVenue(String venueId) => _venues.doc(venueId).delete();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchVenue(String venueId) =>
      _venues.doc(venueId).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchVenuesByOwner(
    String ownerId,
  ) {
    return _venues
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Future<List<(DocumentSnapshot<Map<String, dynamic>>, double)>>
  queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_venues);
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: kVenueGeoField,
      geopointFrom: (data) => data[kVenueGeoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) {
        var q = query.where('status', isEqualTo: 'approved');
        if (category != null) q = q.where('category', isEqualTo: category);
        return q;
      },
      // Without this, GeoFlutterFire returns every doc in the covering
      // geohash cells, which is a slightly larger area than the exact
      // circle — strict mode does the final precise-distance cut so
      // the radius the user picked is the radius they actually get.
      strictMode: true,
    );
    return results
        .map((r) => (r.documentSnapshot, r.distanceFromCenterInKm))
        .toList();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(
    String country, {
    String? category,
  }) {
    var query = _venues
        .where('status', isEqualTo: 'approved')
        .where('country', isEqualTo: country);
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(300).get();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({
    required int limit,
    String? category,
  }) {
    var query = _venues.where('status', isEqualTo: 'approved');
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(limit).get();
  }

  @override
  Future<String> uploadVenuePhoto(
    String venueId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  }) async {
    final storageRef = _storage.ref('venue_photos/$venueId.jpg');
    final task = storageRef.putFile(
      photo,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    onTaskReady?.call(task.cancel);

    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    await task;
    return storageRef.getDownloadURL();
  }

  @override
  Future<void> deleteVenuePhoto(String venueId) async {
    try {
      await _storage.ref('venue_photos/$venueId.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  CollectionReference<Map<String, dynamic>> _likes(String venueId) =>
      _venues.doc(venueId).collection('likes');

  @override
  Stream<bool> watchIsLikedByMe(String venueId, String uid) {
    return _likes(venueId).doc(uid).snapshots().map((doc) => doc.exists);
  }

  @override
  Future<void> setLiked({
    required String uid,
    required String venueId,
    required bool isLiked,
  }) async {
    final likeDoc = _likes(venueId).doc(uid);
    if (isLiked) {
      await likeDoc.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await likeDoc.delete();
    }
    // Deliberately NOT touching likeCount/rating here — the
    // onVenueLikeCreated/onVenueLikeDeleted Cloud Function triggers
    // own those fields exclusively (see functions/src/index.ts).
  }

  /// Matches CHECKIN_EXPIRY_MS in functions/src/index.ts — kept as one
  /// literal in each runtime since Dart and TS can't share a constant,
  /// but both must agree or the live count and the scheduled cleanup
  /// would disagree about what "stale" means.
  static const _checkinExpiry = Duration(hours: 2);

  CollectionReference<Map<String, dynamic>> _activeCheckins(String venueId) =>
      _venues.doc(venueId).collection('activeCheckins');

  @override
  Stream<int> watchActiveCheckinCount(String venueId) {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(_checkinExpiry));
    return _activeCheckins(venueId)
        .where('createdAt', isGreaterThan: cutoff)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Stream<bool> watchIsCheckedInHere(String venueId, String uid) {
    return _activeCheckins(
      venueId,
    ).doc(uid).snapshots().map((doc) => doc.exists);
  }

  @override
  Future<void> checkIn({required String uid, required String venueId}) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final oldVenueId = userSnap.data()?['activeCheckinVenueId'] as String?;
      if (oldVenueId != null && oldVenueId != venueId) {
        tx.delete(_activeCheckins(oldVenueId).doc(uid));
      }
      tx.set(_activeCheckins(venueId).doc(uid), {
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {'activeCheckinVenueId': venueId});
    });
  }

  @override
  Future<void> checkOut({required String uid}) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final venueId = userSnap.data()?['activeCheckinVenueId'] as String?;
      if (venueId == null) return;
      tx.delete(_activeCheckins(venueId).doc(uid));
      tx.update(userRef, {'activeCheckinVenueId': null});
    });
  }
}
