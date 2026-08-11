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
    ActiveHours? activeHours,
    List<String> activeDays,
    String? birthdayMatchId,
    List<String> targetUserIds,
    String? personalMessage,
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
    ActiveHours? activeHours,
    List<String> activeDays,
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

  /// Moves a `needs_revision` offer back to `pending` after the owner
  /// has edited it — mirrors `VenueRepository.resubmitVenue`.
  Future<void> resubmitOffer(String offerId);

  /// Sets `Offer.boostedUntil` to now + [duration] — the owner-only
  /// "Təklifi önə çək" action on Offer Details. No proximity/ownership
  /// check here; the caller (`OfferController.boostOffer`) is the only
  /// client path to this, gated by the UI only showing the boost
  /// control to `offer.isOwnedBy(currentUid)`.
  Future<void> boostOffer(String offerId, Duration duration);

  /// Backs the `birthday_match` push's deep link
  /// (`notification_navigation.dart`) — reads the venue + matched uids
  /// a `computeBirthdayMatches` run wrote, so `CreateOfferScreen` can
  /// pre-fill `preselectedVenueId`/`birthdayTargetUserIds`. Null if the
  /// match doc doesn't exist (e.g. already deleted/pruned).
  Future<({String venueId, List<String> matchedUserIds})?> fetchBirthdayMatch(String matchId);

  /// Whether [uid] has already activated this `OfferType.firstVisit`
  /// offer — backs Offer Details' "Aktivləşdir"/"İstifadə edilib"
  /// button.
  Stream<bool> watchIsRedeemedByMe(String offerId, String uid);

  /// The one-time "Aktivləşdir" action for `OfferType.firstVisit`.
  Future<void> redeemOffer(String offerId, String uid);
}
