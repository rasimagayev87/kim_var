import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Raw Firestore/Storage access for the `pinboxes` collection — mirrors
/// `OfferRemoteDatasource`'s shape.
abstract class PinBoxRemoteDatasource {
  String allocatePinBoxId();

  Future<void> setPinBox(String pinboxId, Map<String, dynamic> data);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPinBox(String pinboxId);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPinBoxesByOwner(String ownerId);

  Future<String> uploadPinBoxPhoto(
    String pinboxId,
    File photo, {
    ValueChanged<double>? onProgress,
    ValueChanged<VoidCallback>? onTaskReady,
  });

  /// Owner-only edit — same "everything except status/review/stockRemaining"
  /// scope as firestore.rules' `pinboxes/{id}` update rule.
  Future<void> updatePinBox(String pinboxId, Map<String, dynamic> data);

  Future<void> deletePinBox(String pinboxId);

  Future<void> deletePinBoxPhoto(String pinboxId);

  /// Admin-approved ('active') boxes within [radiusKm] of a point,
  /// paired with their distance — a still-'active' box with
  /// `stockRemaining == 0` IS included (rendered "Satılıb"/disabled by
  /// the UI, never dropped from the list — see `PinBox.isSoldOut`), so
  /// this deliberately does NOT filter on stock, only on moderation
  /// status.
  Future<List<(DocumentSnapshot<Map<String, dynamic>>, double)>> queryWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  });

  /// Backs "Ölkə üzrə" — mirrors `OfferRemoteDatasource.queryByCountry`.
  Future<QuerySnapshot<Map<String, dynamic>>> queryByCountry(String country, {String? category});

  /// Backs "Dünya üzrə" — mirrors `OfferRemoteDatasource.queryAllActive`.
  Future<QuerySnapshot<Map<String, dynamic>>> queryAllActive({required int limit, String? category});

  /// PinBox Faza 8's ticket screen — the order doc is written
  /// exclusively by Cloud Functions (`reservePinBoxOrder`/
  /// `generatePinBoxQrToken`), this is read-only from the client.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPinBoxOrder(String orderId);

  /// PinBox Faza 11's "Aldıqlarım" — every order this uid ever bought.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOrdersByBuyer(String buyerId);
}
