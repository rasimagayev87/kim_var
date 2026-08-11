import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'offer_remote_datasource.dart';

/// Same field name/shape as `kVenueGeoField` in the venues feature —
/// kept as its own constant (not imported from venues) since this is
/// the offers collection's own document shape, not a shared one; the
/// two features just happen to use the same GeoFlutterFire convention.
const kOfferGeoField = 'position';

class FirebaseOfferRemoteDatasource implements OfferRemoteDatasource {
  FirebaseOfferRemoteDatasource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _offers => _firestore.collection('offers');

  @override
  String allocateOfferId() => _offers.doc().id;

  @override
  Future<void> setOffer(String offerId, Map<String, dynamic> data) => _offers.doc(offerId).set(data);

  @override
  Future<void> updateOffer(String offerId, Map<String, dynamic> data) => _offers.doc(offerId).update(data);

  @override
  Future<void> deleteOffer(String offerId) => _offers.doc(offerId).delete();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOffer(String offerId) => _offers.doc(offerId).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOffersByOwner(String ownerId) {
    return _offers.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).snapshots();
  }

  @override
  Future<List<(DocumentSnapshot<Map<String, dynamic>>, double)>> queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_offers);
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: kOfferGeoField,
      geopointFrom: (data) => data[kOfferGeoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) {
        var q = query.where('status', isEqualTo: 'approved');
        if (category != null) q = q.where('category', isEqualTo: category);
        return q;
      },
      strictMode: true,
    );
    return results.map((r) => (r.documentSnapshot, r.distanceFromCenterInKm)).toList();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryByVenue(String venueId) {
    return _offers.where('venueId', isEqualTo: venueId).where('status', isEqualTo: 'approved').get();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category}) {
    var query = _offers.where('status', isEqualTo: 'approved').where('country', isEqualTo: country);
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(300).get();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category}) {
    var query = _offers.where('status', isEqualTo: 'approved');
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(limit).get();
  }

  @override
  Future<String> uploadOfferPhoto(
    String offerId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  }) async {
    final storageRef = _storage.ref('offer_photos/$offerId.jpg');
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
  Future<void> deleteOfferPhoto(String offerId) async {
    try {
      await _storage.ref('offer_photos/$offerId.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  CollectionReference<Map<String, dynamic>> _favoriteOffers(String uid) =>
      _firestore.collection('users').doc(uid).collection('favoriteOffers');

  @override
  Stream<Set<String>> watchFavoriteOfferIds(String uid) {
    return _favoriteOffers(uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<void> setFavorite({required String uid, required String offerId, required bool isFavorite}) async {
    final favoriteDoc = _favoriteOffers(uid).doc(offerId);
    if (isFavorite) {
      await favoriteDoc.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await favoriteDoc.delete();
    }
  }

  CollectionReference<Map<String, dynamic>> _redemptions(String offerId) =>
      _offers.doc(offerId).collection('redemptions');

  @override
  Stream<bool> watchIsRedeemedByMe(String offerId, String uid) {
    return _redemptions(offerId).doc(uid).snapshots().map((doc) => doc.exists);
  }

  @override
  Future<void> redeemOffer(String offerId, String uid) async {
    await _redemptions(offerId).doc(uid).set({'redeemedAt': FieldValue.serverTimestamp()});
  }
}
