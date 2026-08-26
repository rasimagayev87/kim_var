import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/firestore_retry.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../datasources/firebase_venue_remote_datasource.dart';
import '../datasources/venue_remote_datasource.dart';

/// Maps between the domain `Venue` model and [VenueRemoteDatasource]'s
/// raw Firestore/Storage primitives — this class owns "what shape does
/// a venue document have" and "how do I turn form input into that
/// shape", while the datasource just persists/queries whatever map
/// it's handed.
class FirebaseVenueRepository implements VenueRepository {
  FirebaseVenueRepository({
    VenueRemoteDatasource? datasource,
    FirebaseFunctions? functions,
  }) : _datasource = datasource ?? FirebaseVenueRemoteDatasource(),
       _functions = functions ?? FirebaseFunctions.instance;

  final VenueRemoteDatasource _datasource;
  final FirebaseFunctions _functions;

  @override
  Future<SubmitVenueResult> createVenue({
    required String ownerId,
    required String name,
    required VenueCategory category,
    required File photo,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    VenueSocialLinks? socialLinks,
    String audienceRadiusMode = 'distance',
    double audienceRadiusKm = 1.0,
    bool birthdayNotificationsEnabled = false,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final venueId = _datasource.allocateVenueId();
    final photoUrl = await _datasource.uploadVenuePhoto(
      venueId,
      photo,
      onProgress: onUploadProgress,
      onTaskReady: onUploadTaskReady,
    );

    final result = await _functions.httpsCallable('submitVenue').call<Map<String, dynamic>>({
      'venueId': venueId,
      'name': name,
      'category': category.name,
      'photoUrl': photoUrl,
      'lat': lat,
      'lng': lng,
      'address': address,
      if (country != null) 'country': country,
      'openingHours': openingHours.toMap(),
      if (socialLinks != null && !socialLinks.isEmpty) 'socialLinks': socialLinks.toMap(),
      'audienceRadiusMode': audienceRadiusMode,
      'audienceRadiusKm': audienceRadiusKm,
      'birthdayNotificationsEnabled': birthdayNotificationsEnabled,
    });

    final data = result.data;
    return (
      venueId: data['venueId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Future<bool> updateVenue({
    required String venueId,
    required String name,
    required VenueCategory category,
    File? photo,
    required double lat,
    required double lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    VenueSocialLinks? socialLinks,
    String audienceRadiusMode = 'distance',
    double audienceRadiusKm = 1.0,
    bool birthdayNotificationsEnabled = false,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _datasource.uploadVenuePhoto(
        venueId,
        photo,
        onProgress: onUploadProgress,
        onTaskReady: onUploadTaskReady,
      );
    }

    final result = await _functions.httpsCallable('updateVenue').call<Map<String, dynamic>>({
      'venueId': venueId,
      'name': name,
      'category': category.name,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'lat': lat,
      'lng': lng,
      'address': address,
      if (country != null) 'country': country,
      'openingHours': openingHours.toMap(),
      if (socialLinks != null && !socialLinks.isEmpty) 'socialLinks': socialLinks.toMap(),
      'audienceRadiusMode': audienceRadiusMode,
      'audienceRadiusKm': audienceRadiusKm,
      'birthdayNotificationsEnabled': birthdayNotificationsEnabled,
    });

    return result.data['sentForReReview'] as bool;
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    await _datasource.deleteVenue(venueId);
    await _datasource.deleteVenuePhoto(venueId);
  }

  @override
  Stream<Venue?> watchVenue(String venueId) {
    return _datasource
        .watchVenue(venueId)
        .map(
          (doc) => doc.exists ? Venue.fromFirestore(doc.id, doc.data()!) : null,
        );
  }

  @override
  Stream<List<Venue>> watchMyVenues(String ownerId) {
    return _datasource
        .watchVenuesByOwner(ownerId)
        .map(
          (snap) => snap.docs
              .map((d) => Venue.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<List<VenueWithDistance>> fetchVenuesWithinRadius({
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
        .map(
          (r) => (
            venue: Venue.fromFirestore(r.$1.id, r.$1.data()!),
            distanceMeters: r.$2 * 1000,
          ),
        )
        .toList();
  }

  @override
  Future<List<Venue>> fetchVenuesByCountry(
    String country, {
    VenueCategory? category,
  }) async {
    final snap = await withPermissionRetry(() => _datasource.queryByCountry(
          country,
          category: category?.name,
        ));
    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<Venue>> fetchAllActiveVenues({
    int limit = 300,
    VenueCategory? category,
  }) async {
    final snap = await withPermissionRetry(() => _datasource.queryAllActive(
          limit: limit,
          category: category?.name,
        ));
    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Stream<bool> watchIsLikedByMe(String venueId, String uid) =>
      _datasource.watchIsLikedByMe(venueId, uid);

  @override
  Future<void> setLiked({
    required String uid,
    required String venueId,
    required bool isLiked,
  }) {
    return _datasource.setLiked(uid: uid, venueId: venueId, isLiked: isLiked);
  }

  @override
  Stream<int> watchActiveCheckinCount(String venueId) =>
      _datasource.watchActiveCheckinCount(venueId);

  @override
  Stream<bool> watchIsCheckedInHere(String venueId, String uid) =>
      _datasource.watchIsCheckedInHere(venueId, uid);

  @override
  Future<void> checkIn({required String uid, required String venueId}) =>
      _datasource.checkIn(uid: uid, venueId: venueId);

  @override
  Future<void> checkOut({required String uid}) =>
      _datasource.checkOut(uid: uid);

  @override
  Future<void> resubmitVenue(String venueId) async {
    await _functions.httpsCallable('resubmitVenue').call<Map<String, dynamic>>({
      'venueId': venueId,
    });
  }

  @override
  Future<({String checkoutUrl, double feeAmount, String paymentId})> retryVenueSubscriptionPayment(String venueId) async {
    final result = await _functions.httpsCallable('retryVenueSubscriptionPayment').call<Map<String, dynamic>>({
      'venueId': venueId,
    });
    final data = result.data;
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Future<({String checkoutUrl, double feeAmount, String paymentId})> retryVenueCreationPayment(String venueId) async {
    final result = await _functions.httpsCallable('retryVenueCreationPayment').call<Map<String, dynamic>>({
      'venueId': venueId,
    });
    final data = result.data;
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Future<({String checkoutUrl, double feeAmount, String paymentId})> createVenuePremiumCheckout(String venueId, int months) async {
    final result = await _functions.httpsCallable('createVenuePremiumCheckout').call<Map<String, dynamic>>({
      'venueId': venueId,
      'months': months,
    });
    final data = result.data;
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      feeAmount: (data['feeAmount'] as num).toDouble(),
      paymentId: data['paymentId'] as String,
    );
  }

  @override
  Future<void> dismissFirstPaymentAnnouncement(String venueId) {
    return _datasource.updateVenue(venueId, {'firstPaymentAnnouncementPending': false});
  }

  @override
  Future<void> updateAvailableSeats({required String venueId, required int availableSeats}) {
    return _datasource.updateVenue(venueId, {
      'availableSeats': availableSeats,
      'seatsUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
