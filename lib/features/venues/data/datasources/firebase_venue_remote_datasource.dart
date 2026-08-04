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
  FirebaseVenueRemoteDatasource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _venues => _firestore.collection('venues');

  @override
  String allocateVenueId() => _venues.doc().id;

  @override
  Future<void> setVenue(String venueId, Map<String, dynamic> data) => _venues.doc(venueId).set(data);

  @override
  Future<void> updateVenue(String venueId, Map<String, dynamic> data) => _venues.doc(venueId).update(data);

  @override
  Future<void> deleteVenue(String venueId) => _venues.doc(venueId).delete();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchVenue(String venueId) => _venues.doc(venueId).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchVenuesByOwner(String ownerId) {
    return _venues.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).snapshots();
  }

  @override
  Future<List<(DocumentSnapshot<Map<String, dynamic>>, double)>> queryWithinRadius({
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
        var q = query.where('status', isEqualTo: 'active');
        if (category != null) q = q.where('category', isEqualTo: category);
        return q;
      },
      // Without this, GeoFlutterFire returns every doc in the covering
      // geohash cells, which is a slightly larger area than the exact
      // circle — strict mode does the final precise-distance cut so
      // the radius the user picked is the radius they actually get.
      strictMode: true,
    );
    return results.map((r) => (r.documentSnapshot, r.distanceFromCenterInKm)).toList();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category}) {
    var query = _venues.where('status', isEqualTo: 'active').where('country', isEqualTo: country);
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(300).get();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category}) {
    var query = _venues.where('status', isEqualTo: 'active');
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
    final task = storageRef.putFile(photo, SettableMetadata(contentType: 'image/jpeg'));

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

  CollectionReference<Map<String, dynamic>> _favorites(String uid) =>
      _firestore.collection('users').doc(uid).collection('favorites');

  @override
  Stream<Set<String>> watchFavoriteVenueIds(String uid) {
    return _favorites(uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<void> setFavorite({required String uid, required String venueId, required bool isFavorite}) async {
    final favoriteDoc = _favorites(uid).doc(venueId);
    if (isFavorite) {
      await favoriteDoc.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await favoriteDoc.delete();
    }
    await _venues.doc(venueId).update({'favoriteCount': FieldValue.increment(isFavorite ? 1 : -1)});
  }
}
