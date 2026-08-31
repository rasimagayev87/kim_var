import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/utils/exif_stripper.dart';
import '../../../../core/utils/storage_deletion.dart';
import 'pinbox_remote_datasource.dart';

/// Same GeoFlutterFire field name/shape as `kOfferGeoField` — written
/// from Faza 4 on so PinBox Faza 6's within-radius query has geo data
/// to read from day one, even though no query method reads this field
/// yet.
const kPinBoxGeoField = 'position';

class FirebasePinBoxRemoteDatasource implements PinBoxRemoteDatasource {
  FirebasePinBoxRemoteDatasource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _pinboxes => _firestore.collection('pinboxes');
  CollectionReference<Map<String, dynamic>> get _pinboxOrders => _firestore.collection('pinboxOrders');

  @override
  String allocatePinBoxId() => _pinboxes.doc().id;

  @override
  Future<void> setPinBox(String pinboxId, Map<String, dynamic> data) => _pinboxes.doc(pinboxId).set(data);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPinBox(String pinboxId) => _pinboxes.doc(pinboxId).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPinBoxesByOwner(String ownerId) {
    return _pinboxes.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).snapshots();
  }

  @override
  Future<String> uploadPinBoxPhoto(
    String ownerId,
    String pinboxId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  }) async {
    final storageRef = _storage.ref('pinbox_photos/$ownerId/$pinboxId.jpg');
    // GPS EXIF strip (Düzəliş Prompt 3 / C#43).
    final stripped = await stripExifIfImage(photo);
    final task = storageRef.putFile(stripped, SettableMetadata(contentType: 'image/jpeg'));

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
  Future<void> deletePinBox(String pinboxId) => _pinboxes.doc(pinboxId).delete();

  @override
  Future<void> deletePinBoxPhoto(String ownerId, String pinboxId) async {
    try {
      await deleteWithResizedVariant(_storage.ref('pinbox_photos/$ownerId/$pinboxId.jpg'));
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<List<(DocumentSnapshot<Map<String, dynamic>>, double)>> queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_pinboxes);
    final results = await geoCollection.fetchWithinWithDistance(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: kPinBoxGeoField,
      geopointFrom: (data) => data[kPinBoxGeoField]['geopoint'] as GeoPoint,
      queryBuilder: (query) {
        var q = query.where('status', isEqualTo: 'active');
        if (category != null) q = q.where('category', isEqualTo: category);
        return q;
      },
      strictMode: true,
    );
    return results.map((r) => (r.documentSnapshot, r.distanceFromCenterInKm)).toList();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category}) {
    var query = _pinboxes.where('status', isEqualTo: 'active').where('country', isEqualTo: country);
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(300).get();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category}) {
    var query = _pinboxes.where('status', isEqualTo: 'active');
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.limit(limit).get();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPinBoxOrder(String orderId) => _pinboxOrders.doc(orderId).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOrdersByBuyer(String buyerId) {
    return _pinboxOrders.where('buyerId', isEqualTo: buyerId).orderBy('createdAt', descending: true).snapshots();
  }
}
