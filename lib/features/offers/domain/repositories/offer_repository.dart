import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../entities/offer.dart';

/// An offer paired with its distance from the point a query was
/// centered on, in metres — mirrors `VenueWithDistance`.
typedef OfferWithDistance = ({Offer offer, double distanceMeters});

/// [requiresPayment] false means the offer was free (founding-venue
/// quota) and is already `pending`, in normal moderation — nothing
/// further to do. True means it's `awaiting_payment`, invisible to
/// everyone until the owner completes [checkoutUrl] and
/// `epointWebhook` (functions/src/index.ts) confirms the charge.
typedef SubmitOfferResult = ({String offerId, bool requiresPayment, String? checkoutUrl, double? feeAmount});

abstract class OfferRepository {
  /// `venueName`/`venuePhotoUrl`/`lat`/`lng`/`address`/`category` are
  /// no longer client-supplied — `submitOffer` (Cloud Function,
  /// functions/src/index.ts) derives them from [venueId]'s own venue
  /// doc server-side, same reasoning as the offer-category fix earlier
  /// this project's history, just enforced one layer deeper now that
  /// creation itself moved server-side (see this method's own
  /// implementation doc comment for why: the founding-venue free-quota
  /// decrement needs a real transaction, which firestore.rules alone
  /// can't guarantee race-safety for).
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
    List<String> activeDays,
    String? birthdayMatchId,
    List<String> targetUserIds,
    String? personalMessage,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  /// Re-opens a checkout for an `awaiting_payment` offer whose previous
  /// Epoint attempt failed or was abandoned — same `payments` doc, a
  /// fresh checkout URL. Throws if the offer isn't actually awaiting
  /// payment (already paid, or never needed to be).
  Future<({String checkoutUrl, double feeAmount})> retryOfferPayment(String offerId);

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

  /// Starts an Epoint checkout for one of the 6/12/18-hour "Təklifi önə
  /// çək" tiers — `Offer.boostedUntil` is set only by `epointWebhook`
  /// (functions/src/index.ts) once the charge is confirmed, never
  /// directly from here (see firestore.rules' offers update rule).
  Future<({String checkoutUrl, double feeAmount})> createBoostCheckout(String offerId, int hours);

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
