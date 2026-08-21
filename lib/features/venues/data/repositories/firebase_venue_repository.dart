import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../../../../core/data/listing_payment.dart';
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

  /// The first cycle's charge is written at creation time (this class's
  /// `createVenue`); every cycle after that is `renewVenueSubscriptions`
  /// (scheduled Cloud Function, functions/src/index.ts) — no payment
  /// provider (Epoint/Payriff/LEOpay) is wired yet, so neither one is
  /// ever actually charged. Real billing arrives with that integration;
  /// until then both just give each cycle's `payments/{paymentId}` doc
  /// a plausible `amount` to carry.
  ///
  /// Official per-category tariff — "Məkanlar üzrə aylıq abunəlik
  /// tarifləri", signed by the company director (R. G. Ağayev),
  /// PeakPin_Mekan_Abunelik_Tarifleri.pdf. Exhaustive (no `_` catch-all
  /// on purpose) so adding a 40th category is a compile error here
  /// until it's given a real tier, not a silent 5 AZN default. Kept in
  /// sync by hand with the identical table in functions/src/index.ts
  /// (`venueSubscriptionFeeFor`) — Cloud Functions can't import this
  /// Dart file, so it's independently declared there, not shared code.
  static double _venueListingFeeFor(VenueCategory category) {
    return switch (category) {
      VenueCategory.restaurant => 30.0,
      VenueCategory.pub => 30.0,
      VenueCategory.coffeeShop => 25.0,
      VenueCategory.fastFood => 25.0,
      VenueCategory.teaHouse => 15.0,
      VenueCategory.sweetsShop => 20.0,
      VenueCategory.hotel => 30.0,
      VenueCategory.motel => 20.0,
      VenueCategory.cinema => 30.0,
      VenueCategory.karaoke => 30.0,
      VenueCategory.gameHall => 30.0,
      VenueCategory.nightClub => 30.0,
      VenueCategory.fitness => 30.0,
      VenueCategory.gym => 30.0,
      VenueCategory.spa => 30.0,
      VenueCategory.footballField => 25.0,
      VenueCategory.clinic => 30.0,
      VenueCategory.beautySalon => 30.0,
      VenueCategory.barbershop => 20.0,
      VenueCategory.cosmetology => 30.0,
      VenueCategory.tattoo => 20.0,
      VenueCategory.photoStudio => 20.0,
      VenueCategory.kidsEntertainment => 30.0,
      VenueCategory.tailor => 15.0,
      VenueCategory.dryCleaning => 25.0,
      VenueCategory.pharmacyOptics => 30.0,
      VenueCategory.supermarket => 30.0,
      VenueCategory.carWash => 20.0,
      VenueCategory.carRepair => 20.0,
      VenueCategory.applianceRepair => 20.0,
      VenueCategory.tutoringCenter => 25.0,
      VenueCategory.bookstoreStationery => 20.0,
      VenueCategory.dentalClinic => 30.0,
      VenueCategory.petStore => 20.0,
      VenueCategory.perfumeryCosmetics => 25.0,
      VenueCategory.other => 25.0,
      // Added after the tariff PDF — not on it, priced per the task
      // that introduced them (session-approved, not director-signed).
      VenueCategory.wineBar => 30.0,
      VenueCategory.cleaningServices => 20.0,
      VenueCategory.independentArtist => 30.0,
    };
  }

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

    final paymentId = await createListingPayment(
      ownerId: ownerId,
      listingType: 'venue',
      listingId: venueId,
      type: 'venue_subscription',
      amount: _venueListingFeeFor(category),
    );

    // First cycle only — `renewVenueSubscriptions` takes over from here,
    // pushing this forward another 30 days (and writing that cycle's own
    // `payments` doc) each time it fires. Not `FieldValue.serverTimestamp()`
    // plus a client-side add: computed from `DateTime.now()` so the 30-day
    // offset is exact regardless of server-timestamp resolution latency.
    final subscriptionRenewsAt = DateTime.now().add(const Duration(days: 30));

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
      'subscriptionRenewsAt': Timestamp.fromDate(subscriptionRenewsAt),
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
  Future<void> updateAvailableSeats({required String venueId, required int availableSeats}) {
    return _datasource.updateVenue(venueId, {
      'availableSeats': availableSeats,
      'seatsUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
