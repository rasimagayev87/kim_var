import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/utils/firestore_retry.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../domain/entities/pinbox.dart';
import '../../domain/entities/pinbox_order.dart';
import '../../domain/repositories/pinbox_repository.dart';
import '../datasources/firebase_pinbox_remote_datasource.dart';
import '../datasources/pinbox_remote_datasource.dart';

class FirebasePinBoxRepository implements PinBoxRepository {
  FirebasePinBoxRepository({PinBoxRemoteDatasource? datasource, FirebaseFunctions? functions})
      : _datasource = datasource ?? FirebasePinBoxRemoteDatasource(),
        _functions = functions ?? FirebaseFunctions.instance;

  final PinBoxRemoteDatasource _datasource;
  final FirebaseFunctions _functions;

  @override
  Future<String> createPinBox({
    required String ownerId,
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required VenueCategory category,
    required String title,
    required String description,
    required File? photo,
    required double originalPrice,
    required double pinboxPrice,
    required int stockTotal,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final pinboxId = _datasource.allocatePinBoxId();
    String? imageUrl;
    if (photo != null) {
      imageUrl = await _datasource.uploadPinBoxPhoto(
        pinboxId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    await _datasource.setPinBox(pinboxId, {
      'ownerId': ownerId,
      'venueId': venueId,
      'venueName': venueName,
      'venuePhotoUrl': venuePhotoUrl,
      'lat': lat,
      'lng': lng,
      kPinBoxGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      if (country != null) 'country': country,
      'category': category.name,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'pinboxPrice': pinboxPrice,
      'stockTotal': stockTotal,
      'stockRemaining': stockTotal,
      'pickupWindowStart': Timestamp.fromDate(pickupWindowStart),
      'pickupWindowEnd': Timestamp.fromDate(pickupWindowEnd),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return pinboxId;
  }

  @override
  Future<void> updatePinBox({
    required String pinboxId,
    required String title,
    required String description,
    required double originalPrice,
    required double pinboxPrice,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    File? photo,
    required bool hasExistingPhoto,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    String? imageUrl;
    if (photo != null) {
      imageUrl = await _datasource.uploadPinBoxPhoto(
        pinboxId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    await _datasource.updatePinBox(pinboxId, {
      'title': title,
      'description': description,
      'originalPrice': originalPrice,
      'pinboxPrice': pinboxPrice,
      'pickupWindowStart': Timestamp.fromDate(pickupWindowStart),
      'pickupWindowEnd': Timestamp.fromDate(pickupWindowEnd),
      'updatedAt': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  @override
  Future<void> deletePinBox(String pinboxId) async {
    await _datasource.deletePinBox(pinboxId);
    await _datasource.deletePinBoxPhoto(pinboxId);
  }

  @override
  Future<void> resubmitPinBox(String pinboxId) async {
    await _functions.httpsCallable('resubmitPinBox').call<Map<String, dynamic>>({
      'pinboxId': pinboxId,
    });
  }

  @override
  Stream<PinBox?> watchPinBox(String pinboxId) {
    return _datasource.watchPinBox(pinboxId).map((doc) => doc.exists ? PinBox.fromFirestore(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<PinBox>> watchMyPinBoxes(String ownerId) {
    return _datasource
        .watchPinBoxesByOwner(ownerId)
        .map((snap) => snap.docs.map((doc) => PinBox.fromFirestore(doc.id, doc.data())).toList());
  }

  /// Excludes a box whose same-day pickup window has already ended,
  /// even if `status` is still `active` and stock remains — nothing
  /// writes `status: 'expired'` on a schedule (unlike sold-out, which
  /// `reservePinBoxOrder`'s own transaction flips synchronously), so
  /// this client-side filter is the only thing hiding it from discovery
  /// once ordering it would no longer make sense. Applied uniformly
  /// across all 3 fetch methods below.
  bool _isWithinPickupWindow(PinBox pinbox) => pinbox.pickupWindowEnd.isAfter(DateTime.now());

  @override
  Future<List<PinBoxWithDistance>> fetchPinBoxesWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  }) async {
    final results = await withPermissionRetry(() => _datasource.queryWithinRadius(
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          category: category?.name,
        ));

    return results
        .map((r) => (pinbox: PinBox.fromFirestore(r.$1.id, r.$1.data()!), distanceMeters: r.$2 * 1000))
        .where((r) => _isWithinPickupWindow(r.pinbox))
        .toList();
  }

  @override
  Future<List<PinBox>> fetchPinBoxesByCountry(String country, {VenueCategory? category}) async {
    final snap = await withPermissionRetry(() => _datasource.queryByCountry(country, category: category?.name));
    return snap.docs.map((d) => PinBox.fromFirestore(d.id, d.data())).where(_isWithinPickupWindow).toList();
  }

  @override
  Future<List<PinBox>> fetchAllActivePinBoxes({int limit = 300, VenueCategory? category}) async {
    final snap = await withPermissionRetry(() => _datasource.queryAllActive(limit: limit, category: category?.name));
    return snap.docs.map((d) => PinBox.fromFirestore(d.id, d.data())).where(_isWithinPickupWindow).toList();
  }

  @override
  Future<String> reservePinBoxOrder({required String pinboxId, int quantity = 1}) async {
    final result = await _functions.httpsCallable('reservePinBoxOrder').call<Map<String, dynamic>>({
      'pinboxId': pinboxId,
      'quantity': quantity,
    });
    return result.data['orderId'] as String;
  }

  @override
  Stream<PinBoxOrder?> watchPinBoxOrder(String orderId) {
    return _datasource
        .watchPinBoxOrder(orderId)
        .map((doc) => doc.exists ? PinBoxOrder.fromFirestore(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<PinBoxOrder>> watchMyOrders(String buyerId) {
    return _datasource
        .watchOrdersByBuyer(buyerId)
        .map((snap) => snap.docs.map((doc) => PinBoxOrder.fromFirestore(doc.id, doc.data())).toList());
  }

  @override
  Future<({String qrToken, DateTime expiresAt})> generateQrToken(String orderId) async {
    final result = await _functions.httpsCallable('generatePinBoxQrToken').call<Map<String, dynamic>>({
      'orderId': orderId,
    });
    final qrToken = result.data['qrToken'] as String;
    final expiresAtMs = result.data['qrTokenExpiresAtMs'] as int;
    return (qrToken: qrToken, expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs));
  }

  @override
  Future<({String orderId, String pinboxTitle, int quantity})> redeemPinBoxOrder({
    required String venueId,
    required String code,
  }) async {
    final result = await _functions.httpsCallable('redeemPinBoxOrder').call<Map<String, dynamic>>({
      'venueId': venueId,
      'code': code,
    });
    return (
      orderId: result.data['orderId'] as String,
      pinboxTitle: result.data['pinboxTitle'] as String,
      quantity: result.data['quantity'] as int,
    );
  }
}
