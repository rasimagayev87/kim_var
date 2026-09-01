import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/utils/exif_stripper.dart';
import '../../../../core/utils/private_data_ref.dart';
import '../../../../core/utils/storage_deletion.dart';
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
    String ownerId,
    String venueId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  }) async {
    final storageRef = _storage.ref('venue_photos/$ownerId/$venueId.jpg');
    // GPS EXIF strip (Düzəliş Prompt 3 / C#43) — lower priority than
    // profile/chat (a venue's own position is already public), applied
    // uniformly for simplicity, no separate code path.
    final stripped = await stripExifIfImage(photo);
    final task = storageRef.putFile(
      stripped,
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
  Future<void> deleteVenuePhoto(String ownerId, String venueId) async {
    try {
      await deleteWithResizedVariant(
        _storage.ref('venue_photos/$ownerId/$venueId.jpg'),
      );
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

  CollectionReference<Map<String, dynamic>> _activeCheckins(String venueId) =>
      _venues.doc(venueId).collection('activeCheckins');

  @override
  Stream<int> watchActiveCheckinCount(String venueId) {
    // `visibleCheckinCount`, not `activeCheckinCount`. The raw count
    // now lives in `venues/{id}/private/counters`, closed to every
    // client including the venue's owner; this field is that number
    // with the k-anonymity floor applied, so it reads 0 below the
    // threshold. "1 nəfər burada" identifies a specific person, and
    // suppressing it in the widget while the true number sat on a
    // publicly-readable document would have been decoration rather
    // than privacy. See `bumpActiveCheckinCount` (functions/src/
    // index.ts) and docs/VENUE_OCCUPANCY.md.
    //
    // The raw `activeCheckins` subcollection is readable only by the
    // person who checked in.
    return _venues
        .doc(venueId)
        .snapshots()
        .map(
          (snap) => (snap.data()?['visibleCheckinCount'] as num?)?.toInt() ?? 0,
        );
  }

  @override
  Stream<bool> watchIsCheckedInHere(String venueId, String uid) {
    return _activeCheckins(
      venueId,
    ).doc(uid).snapshots().map((doc) => doc.exists);
  }

  @override
  Future<void> checkIn({required String uid, required String venueId}) async {
    // `activeCheckinVenueId` lives on `users/{uid}/private/data`
    // (Düzəliş Prompt 4) — owner-only, same as every other field that
    // moved there.
    final privateRef = privateDataRef(uid, firestore: _firestore);
    await _firestore.runTransaction((tx) async {
      final privateSnap = await tx.get(privateRef);
      final oldVenueId = privateSnap.data()?['activeCheckinVenueId'] as String?;
      if (oldVenueId != null && oldVenueId != venueId) {
        tx.delete(_activeCheckins(oldVenueId).doc(uid));
      }
      tx.set(_activeCheckins(venueId).doc(uid), {
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(privateRef, {
        'activeCheckinVenueId': venueId,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> checkOut({required String uid}) async {
    final privateRef = privateDataRef(uid, firestore: _firestore);
    await _firestore.runTransaction((tx) async {
      final privateSnap = await tx.get(privateRef);
      final venueId = privateSnap.data()?['activeCheckinVenueId'] as String?;
      if (venueId == null) return;
      tx.delete(_activeCheckins(venueId).doc(uid));
      tx.set(privateRef, {
        'activeCheckinVenueId': null,
      }, SetOptions(merge: true));
    });
  }
}
