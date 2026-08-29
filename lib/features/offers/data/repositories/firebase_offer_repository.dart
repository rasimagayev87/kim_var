import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/firestore_retry.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../datasources/firebase_offer_remote_datasource.dart';
import '../datasources/offer_remote_datasource.dart';

class FirebaseOfferRepository implements OfferRepository {
  FirebaseOfferRepository({OfferRemoteDatasource? datasource, FirebaseFunctions? functions})
      : _datasource = datasource ?? FirebaseOfferRemoteDatasource(),
        _functions = functions ?? FirebaseFunctions.instance;

  final OfferRemoteDatasource _datasource;
  final FirebaseFunctions _functions;

  /// See `FirebaseVenueRepository._safeVenue`'s doc comment — same
  /// per-document isolation, applied here for `Offer`.
  Offer? _safeOffer(String id, Map<String, dynamic> data) {
    try {
      return Offer.fromFirestore(id, data);
    } catch (e, st) {
      logError('firebase_offer_repository.Offer.fromFirestore($id)', e, st);
      return null;
    }
  }

  @override
  Future<SubmitOfferResult> createOffer({
    required String venueId,
    required String title,
    required String description,
    required OfferType offerType,
    double? discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required File? photo,
    String? terms,
    ActiveHours? activeHours,
    List<String> activeDays = const [],
    String? birthdayMatchId,
    List<String> targetUserIds = const [],
    String? personalMessage,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final offerId = _datasource.allocateOfferId();
    String? imageUrl;
    if (photo != null) {
      // Storage's own `request.auth.uid == ownerId` check means this
      // MUST be the current signed-in user regardless — `submitOffer`
      // (the Cloud Function) separately re-verifies real venue
      // ownership server-side.
      final ownerId = fb.FirebaseAuth.instance.currentUser!.uid;
      imageUrl = await _datasource.uploadOfferPhoto(
        ownerId,
        offerId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    final result = await _functions.httpsCallable('submitOffer').call<Map<String, dynamic>>({
      'offerId': offerId,
      'venueId': venueId,
      'title': title,
      'description': description,
      'offerType': offerType.name,
      'discountValue': discountValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'imageUrl': imageUrl,
      'terms': terms,
      'activeHours': activeHours?.toMap(),
      'activeDays': activeDays,
      if (birthdayMatchId != null) 'birthdayMatchId': birthdayMatchId,
      if (targetUserIds.isNotEmpty) 'targetUserIds': targetUserIds,
      if (personalMessage != null) 'personalMessage': personalMessage,
    });

    final data = result.data;
    return (
      offerId: offerId,
      requiresPayment: data['requiresPayment'] as bool,
      checkoutUrl: data['checkoutUrl'] as String?,
      feeAmount: (data['feeAmount'] as num?)?.toDouble(),
      paymentId: data['paymentId'] as String?,
    );
  }

  @override
  Future<({String checkoutUrl, double feeAmount, String paymentId})> retryOfferPayment(String offerId) async {
    final result = await _functions.httpsCallable('retryOfferPayment').call<Map<String, dynamic>>({'offerId': offerId});
    final data = result.data;
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Future<bool> updateOffer({
    required String offerId,
    required VenueCategory category,
    required String title,
    required String description,
    required OfferType offerType,
    double? discountValue,
    required DateTime startDate,
    required DateTime endDate,
    File? photo,
    required bool hasExistingPhoto,
    String? terms,
    ActiveHours? activeHours,
    List<String> activeDays = const [],
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    String? imageUrl;
    if (photo != null) {
      // Storage's own `request.auth.uid == ownerId` check means this
      // MUST be the current signed-in user regardless — `updateOffer`
      // (the Cloud Function) separately re-verifies real ownership
      // server-side, so this is never trusted on its own.
      final ownerId = fb.FirebaseAuth.instance.currentUser!.uid;
      imageUrl = await _datasource.uploadOfferPhoto(
        ownerId,
        offerId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    final result = await _functions.httpsCallable('updateOffer').call<Map<String, dynamic>>({
      'offerId': offerId,
      'category': category.name,
      'title': title,
      'description': description,
      'offerType': offerType.name,
      'discountValue': discountValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'terms': terms,
      'activeHours': activeHours?.toMap(),
      'activeDays': activeDays,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });

    return result.data['sentForReReview'] as bool;
  }

  @override
  Future<void> deleteOffer(String offerId) async {
    await _datasource.deleteOffer(offerId);
    await _datasource.deleteOfferPhoto(fb.FirebaseAuth.instance.currentUser!.uid, offerId);
  }

  @override
  Stream<Offer?> watchOffer(String offerId) {
    return _datasource.watchOffer(offerId).map((doc) => doc.exists ? _safeOffer(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<Offer>> watchMyOffers(String ownerId) {
    return _datasource
        .watchOffersByOwner(ownerId)
        .map((snap) => snap.docs.map((d) => _safeOffer(d.id, d.data())).whereType<Offer>().toList());
  }

  @override
  Future<List<Offer>> fetchOtherActiveOffersForVenue(String venueId, {required String excludeOfferId}) async {
    final snap = await _datasource.queryByVenue(venueId);
    final now = DateTime.now();
    return snap.docs
        .where((d) => d.id != excludeOfferId)
        .map((d) => _safeOffer(d.id, d.data()))
        .whereType<Offer>()
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Future<List<OfferWithDistance>> fetchOffersWithinRadius({
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

    final now = DateTime.now();
    return results
        .map((r) => (offer: _safeOffer(r.$1.id, r.$1.data()!), distanceMeters: r.$2 * 1000))
        .where((entry) => entry.offer != null && entry.offer!.endDate.isAfter(now))
        .map((entry) => (offer: entry.offer!, distanceMeters: entry.distanceMeters))
        .toList();
  }

  @override
  Future<List<Offer>> fetchOffersByCountry(String country, {VenueCategory? category}) async {
    final snap = await withPermissionRetry(() => _datasource.queryByCountry(country, category: category?.name));
    final now = DateTime.now();
    return snap.docs
        .map((d) => _safeOffer(d.id, d.data()))
        .whereType<Offer>()
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Future<List<Offer>> fetchAllActiveOffers({int limit = 300, VenueCategory? category}) async {
    final snap = await withPermissionRetry(() => _datasource.queryAllActive(limit: limit, category: category?.name));
    final now = DateTime.now();
    return snap.docs
        .map((d) => _safeOffer(d.id, d.data()))
        .whereType<Offer>()
        .where((offer) => offer.endDate.isAfter(now))
        .toList();
  }

  @override
  Stream<Set<String>> watchFavoriteOfferIds(String uid) => _datasource.watchFavoriteOfferIds(uid);

  @override
  Future<void> setFavorite({required String uid, required String offerId, required bool isFavorite}) {
    return _datasource.setFavorite(uid: uid, offerId: offerId, isFavorite: isFavorite);
  }

  @override
  Future<void> resubmitOffer(String offerId) async {
    await _functions.httpsCallable('resubmitOffer').call<Map<String, dynamic>>({'offerId': offerId});
  }

  @override
  Future<({String checkoutUrl, double feeAmount, String paymentId})> createBoostCheckout(String offerId, int hours) async {
    final result = await _functions.httpsCallable('createBoostCheckout').call<Map<String, dynamic>>({
      'offerId': offerId,
      'hours': hours,
    });
    final data = result.data;
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Stream<bool> watchIsRedeemedByMe(String offerId, String uid) => _datasource.watchIsRedeemedByMe(offerId, uid);

  @override
  Future<void> redeemOffer(String offerId, String uid) => _datasource.redeemOffer(offerId, uid);

  @override
  Future<({String venueId, List<String> matchedUserIds})?> fetchBirthdayMatch(String matchId) async {
    final snap = await FirebaseFirestore.instance.collection('birthdayMatches').doc(matchId).get();
    final data = snap.data();
    if (data == null) return null;
    final venueId = data['venueId'] as String?;
    if (venueId == null) return null;
    return (venueId: venueId, matchedUserIds: (data['matchedUserIds'] as List?)?.cast<String>() ?? const []);
  }
}
