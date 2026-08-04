import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../entities/offer.dart';

/// An offer paired with its distance from the point a query was
/// centered on, in metres — mirrors `VenueWithDistance`.
typedef OfferWithDistance = ({Offer offer, double distanceMeters});

abstract class OfferRepository {
  /// [venueName]/[venuePhotoUrl]/[lat]/[lng]/[address] come from the
  /// already-selected [Venue] in the Create Offer form (see
  /// [OfferRepository] doc) — this never re-fetches the venue doc
  /// itself, the caller already has it.
  Future<String> createOffer({
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
    required OfferType offerType,
    double? discountValue,
    required DateTime startDate,
    required DateTime endDate,
    required File? photo,
    String? terms,
    String? contactPhone,
    bool showContactPhone = false,
    String? contactWebsite,
    bool showContactWebsite = false,
    String? contactInstagram,
    bool showContactInstagram = false,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  Future<void> updateOffer({
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
    String? contactPhone,
    bool showContactPhone = false,
    String? contactWebsite,
    bool showContactWebsite = false,
    String? contactInstagram,
    bool showContactInstagram = false,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  Future<void> deleteOffer(String offerId);

  Stream<Offer?> watchOffer(String offerId);

  /// Every offer this uid has published, regardless of expiry —
  /// mirrors `VenueRepository.watchMyVenues`.
  Stream<List<Offer>> watchMyOffers(String ownerId);

  /// Active, non-expired offers at [venueId] other than [excludeOfferId]
  /// — backs Offer Details' "Digər aktiv təkliflər".
  Future<List<Offer>> fetchOtherActiveOffersForVenue(String venueId, {required String excludeOfferId});

  /// Active, non-expired offers within [radiusKm] of ([lat], [lng]),
  /// optionally narrowed to one [category], sorted nearest-first.
  /// Expiry (`endDate` in the past) is filtered here, not at the
  /// datasource's query level — see
  /// `OfferRemoteDatasource.queryWithinRadius`'s doc comment for why.
  Future<List<OfferWithDistance>> fetchOffersWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  });

  /// Backs "Ölkə üzrə" — mirrors `VenueRepository.fetchVenuesByCountry`.
  Future<List<Offer>> fetchOffersByCountry(String country, {VenueCategory? category});

  /// Backs "Dünya üzrə" — mirrors `VenueRepository.fetchAllActiveVenues`.
  Future<List<Offer>> fetchAllActiveOffers({int limit, VenueCategory? category});

  /// Realtime set of offer ids [uid] has favorited.
  Stream<Set<String>> watchFavoriteOfferIds(String uid);

  Future<void> setFavorite({required String uid, required String offerId, required bool isFavorite});
}
