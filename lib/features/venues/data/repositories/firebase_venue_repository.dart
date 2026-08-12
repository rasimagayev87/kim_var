import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

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

  /// Placeholder listing fee — no payment provider (Epoint/Payriff/
  /// LEOpay) is wired yet, so this is never actually charged. Real
  /// pricing arrives with that integration; until then this just gives
  /// the `payments/{paymentId}` doc a plausible `amount` to carry.
  static const double _venueListingFeeAzn = 5.0;

  @override
  Future<String> createVenue({
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

    final paymentId = await _createListingPayment(ownerId: ownerId, venueId: venueId);

    await _datasource.setVenue(venueId, {
      'ownerId': ownerId,
      'name': name,
      'category': category.name,
      'photoUrl': photoUrl,
      'lat': lat,
      'lng': lng,
      kVenueGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      if (country != null) 'country': country,
      'openingHours': openingHours.toMap(),
      'status': 'pending',
      'paymentId': paymentId,
      'verified': false,
      'likeCount': 0,
      'rating': 3.0,
      if (socialLinks != null && !socialLinks.isEmpty)
        'socialLinks': socialLinks.toMap(),
      'audienceRadiusMode': audienceRadiusMode,
      'audienceRadiusKm': audienceRadiusKm,
      'birthdayNotificationsEnabled': birthdayNotificationsEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return venueId;
  }

  /// Stands in for a real checkout: no payment provider is wired yet
  /// (see the offer-boost TODO in `offer_details_screen.dart` for the
  /// same caveat), so this writes the `payments/{paymentId}` doc
  /// straight to `'completed'` instead of `'pending'` pending a webhook
  /// confirmation. Once a provider exists, this becomes "create
  /// 'pending', redirect to checkout, webhook flips it to 'completed'"
  /// — the rest of the moderation/refund state machine (admin actions,
  /// `expireVenueRevisionDeadlines`, `processPaymentRefund`) doesn't
  /// change either way, since it all keys off this doc's `status`.
  Future<String> _createListingPayment({required String ownerId, required String venueId}) async {
    final ref = FirebaseFirestore.instance.collection('payments').doc();
    await ref.set({
      'ownerId': ownerId,
      'venueId': venueId,
      'type': 'venue_listing',
      'amount': _venueListingFeeAzn,
      'currency': 'AZN',
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateVenue({
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

    await _datasource.updateVenue(venueId, {
      'name': name,
      'category': category.name,
      'lat': lat,
      'lng': lng,
      kVenueGeoField: GeoFirePoint(GeoPoint(lat, lng)).data,
      'address': address,
      'country': country,
      'openingHours': openingHours.toMap(),
      // Always written (even as null) so removing a previously-set
      // link in the edit form actually clears it — same reasoning as
      // `country` above, not left out on the empty case.
      'socialLinks': (socialLinks != null && !socialLinks.isEmpty)
          ? socialLinks.toMap()
          : null,
      'audienceRadiusMode': audienceRadiusMode,
      'audienceRadiusKm': audienceRadiusKm,
      'birthdayNotificationsEnabled': birthdayNotificationsEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
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
    final results = await _datasource.queryWithinRadius(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      category: category?.name,
    );
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
    final snap = await _datasource.queryByCountry(
      country,
      category: category?.name,
    );
    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<Venue>> fetchAllActiveVenues({
    int limit = 300,
    VenueCategory? category,
  }) async {
    final snap = await _datasource.queryAllActive(
      limit: limit,
      category: category?.name,
    );
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
}
