import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../data/datasources/firebase_offer_remote_datasource.dart';
import '../../data/datasources/offer_remote_datasource.dart';
import '../../data/repositories/firebase_offer_repository.dart';
import '../../domain/entities/offer.dart';
import '../../domain/offer_failure.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../domain/usecases/create_offer_usecase.dart';
import '../../domain/usecases/delete_offer_usecase.dart';
import '../../domain/usecases/update_offer_usecase.dart';

export '../../domain/repositories/offer_repository.dart' show OfferWithDistance;

final offerRemoteDatasourceProvider = Provider<OfferRemoteDatasource>((ref) => FirebaseOfferRemoteDatasource());

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  return FirebaseOfferRepository(datasource: ref.watch(offerRemoteDatasourceProvider));
});

final createOfferUseCaseProvider = Provider<CreateOfferUseCase>((ref) {
  return CreateOfferUseCase(ref.watch(offerRepositoryProvider));
});

final updateOfferUseCaseProvider = Provider<UpdateOfferUseCase>((ref) {
  return UpdateOfferUseCase(ref.watch(offerRepositoryProvider));
});

final deleteOfferUseCaseProvider = Provider<DeleteOfferUseCase>((ref) {
  return DeleteOfferUseCase(ref.watch(offerRepositoryProvider));
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final offerByIdProvider = StreamProvider.family<Offer?, String>((ref, offerId) {
  return ref.watch(offerRepositoryProvider).watchOffer(offerId);
});

/// Every offer the signed-in user has published, regardless of expiry
/// — mirrors `myVenuesProvider`.
final myOffersProvider = StreamProvider.autoDispose<List<Offer>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const []);
  return ref.watch(offerRepositoryProvider).watchMyOffers(uid);
});

/// Offer Details' "Digər aktiv təkliflər" section.
final otherOffersForVenueProvider = FutureProvider.autoDispose.family<List<Offer>, ({String venueId, String excludeOfferId})>(
  (ref, args) async {
    final offers =
        await ref.watch(offerRepositoryProvider).fetchOtherActiveOffersForVenue(args.venueId, excludeOfferId: args.excludeOfferId);
    // Same `OfferType.birthday` visibility rule as `nearbyOffersProvider`
    // — this is still an "everyone visiting this venue" surface.
    final myUid = _currentUid();
    return offers
        .where((o) => o.offerType != OfferType.birthday || (myUid != null && o.targetUserIds.contains(myUid)))
        .toList();
  },
);

/// The Filter bottom sheet's selected category — null means "every
/// category". A plain `StateProvider` (not persisted) since it's pure
/// UI filter state, same role as `selectedGenderFilterProvider` for
/// İnsanlar.
final selectedOfferCategoryFilterProvider = StateProvider<VenueCategory?>((ref) => null);

/// Drives every offer write (create/update/delete). Same contract as
/// `VenueController`.
class OfferController {
  OfferController(this._ref);

  final Ref _ref;

  Future<SubmitOfferResult?> createOffer({
    required String? venueId,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    required File? photo,
    String? terms,
    ActiveHours? activeHours,
    List<String> activeDays = const [],
    String? birthdayMatchId,
    List<String> targetUserIds = const [],
    String? personalMessage,
    required void Function(List<OfferFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final result = await _ref.read(createOfferUseCaseProvider).call(
            venueId: venueId,
            title: title,
            description: description,
            category: category,
            offerType: offerType,
            discountValue: discountValue,
            startDate: startDate,
            endDate: endDate,
            photo: photo,
            terms: terms,
            activeHours: activeHours,
            activeDays: activeDays,
            birthdayMatchId: birthdayMatchId,
            targetUserIds: targetUserIds,
            personalMessage: personalMessage,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      // Same staleness gap as nearbyVenuesProvider — a one-shot
      // FutureProvider keyed off position/radius/category, not the
      // offers collection itself. A fee-required offer isn't visible
      // here anyway (still `awaiting_payment`), but the free-quota path
      // is already `pending` and should still trigger this the same
      // way the old direct-write flow did.
      _ref.invalidate(nearbyOffersProvider);
      return result;
    } on OfferValidationException catch (e) {
      onValidationError(e.missingFields);
      return null;
    } catch (e, st) {
      logError('offer_providers.createOffer', e, st);
      onError();
      return null;
    }
  }

  Future<({String checkoutUrl, double feeAmount, String paymentId})?> retryOfferPayment(String offerId) async {
    try {
      return await _ref.read(offerRepositoryProvider).retryOfferPayment(offerId);
    } catch (e, st) {
      logError('offer_providers.retryOfferPayment', e, st);
      return null;
    }
  }

  Future<bool> updateOffer({
    required String offerId,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    File? photo,
    required bool hasExistingPhoto,
    String? terms,
    ActiveHours? activeHours,
    List<String> activeDays = const [],
    required void Function(List<OfferFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    try {
      await _ref.read(updateOfferUseCaseProvider).call(
            offerId: offerId,
            title: title,
            description: description,
            category: category,
            offerType: offerType,
            discountValue: discountValue,
            startDate: startDate,
            endDate: endDate,
            photo: photo,
            hasExistingPhoto: hasExistingPhoto,
            terms: terms,
            activeHours: activeHours,
            activeDays: activeDays,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      _ref.invalidate(nearbyOffersProvider);
      return true;
    } on OfferValidationException catch (e) {
      onValidationError(e.missingFields);
      return false;
    } catch (e, st) {
      logError('offer_providers.updateOffer', e, st);
      onError();
      return false;
    }
  }

  Future<bool> deleteOffer(String offerId, {required void Function() onError}) async {
    try {
      await _ref.read(deleteOfferUseCaseProvider).call(offerId);
      _ref.invalidate(nearbyOffersProvider);
      return true;
    } catch (e, st) {
      logError('offer_providers.deleteOffer', e, st);
      onError();
      return false;
    }
  }

  /// Flips [offerId]'s favorite state for the signed-in user — mirrors
  /// `VenueController.toggleFavorite`.
  Future<bool> toggleFavorite(String offerId, {required bool isCurrentlyFavorite}) async {
    final uid = _currentUid();
    if (uid == null) return false;

    try {
      await _ref.read(offerRepositoryProvider).setFavorite(
            uid: uid,
            offerId: offerId,
            isFavorite: !isCurrentlyFavorite,
          );
      return true;
    } catch (e, st) {
      logError('offer_providers.toggleFavorite', e, st);
      return false;
    }
  }

  /// Mirrors `VenueController.resubmitVenue` — moves a `needs_revision`
  /// offer back to `pending` after the owner has edited it.
  Future<bool> resubmitOffer(String offerId) async {
    try {
      await _ref.read(offerRepositoryProvider).resubmitOffer(offerId);
      return true;
    } catch (e, st) {
      logError('offer_providers.resubmitOffer', e, st);
      return false;
    }
  }

  /// "Təklifi önə çək" — the owner-only boost checkout on Offer Details
  /// (see `_HeroImage` in `offer_details_screen.dart`). No client-side
  /// ownership re-check here; the UI only ever exposes this control to
  /// `offer.isOwnedBy(currentUid)` in the first place. Doesn't set
  /// anything itself — `Offer.boostedUntil` only moves once
  /// `epointWebhook` confirms the charge, so there's nothing to
  /// invalidate here the way the old direct-write version had to.
  Future<({String checkoutUrl, double feeAmount, String paymentId})?> createBoostCheckout(String offerId, int hours) async {
    try {
      return await _ref.read(offerRepositoryProvider).createBoostCheckout(offerId, hours);
    } catch (e, st) {
      logError('offer_providers.createBoostCheckout', e, st);
      return null;
    }
  }

  /// "Aktivləşdir" — the one-time activation action for
  /// `OfferType.firstVisit` (see `_RedeemButton` in
  /// `offer_details_screen.dart`). Firestore rules only grant `create`
  /// on the redemption doc, so a second call for an already-redeemed
  /// offer fails there — the UI already gates the button on
  /// `isOfferRedeemedByMeProvider`, this is a defensive backstop.
  Future<bool> redeemOffer(String offerId) async {
    final uid = _currentUid();
    if (uid == null) return false;

    try {
      await _ref.read(offerRepositoryProvider).redeemOffer(offerId, uid);
      return true;
    } catch (e, st) {
      logError('offer_providers.redeemOffer', e, st);
      return false;
    }
  }
}

final offerControllerProvider = Provider<OfferController>((ref) => OfferController(ref));

/// Realtime set of offer ids the signed-in user has favorited — mirrors
/// `favoriteVenueIdsProvider`.
/// Whether the signed-in user has already activated this
/// `OfferType.firstVisit` offer — backs `_RedeemButton`'s
/// "Aktivləşdir"/"İstifadə edilib" state, mirrors
/// `isVenueLikedByMeProvider`.
final isOfferRedeemedByMeProvider = StreamProvider.autoDispose.family<bool, String>((ref, offerId) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(false);
  return ref.watch(offerRepositoryProvider).watchIsRedeemedByMe(offerId, uid);
});

final favoriteOfferIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const {});
  return ref.watch(offerRepositoryProvider).watchFavoriteOfferIds(uid);
});

/// Wraps active, non-expired offers with real Haversine distance from
/// [position] — mirrors `venue_providers.dart`'s `_withDistanceFrom`
/// for the Ölkə/Dünya modes. Sorting itself happens once, uniformly
/// across all 3 radius modes, in [_sortBoostedFirst] below.
List<OfferWithDistance> _withDistanceFrom(List<Offer> offers, Position position) {
  return offers
      .map(
        (offer) => (
          offer: offer,
          distanceMeters: Geolocator.distanceBetween(position.latitude, position.longitude, offer.lat, offer.lng),
        ),
      )
      .toList();
}

/// "Təklifi önə çək" (`OfferController.createBoostCheckout`) has one real,
/// visible effect: while `Offer.isBoosted`, it sorts ahead of every
/// non-boosted offer, ties broken by distance — same nearest-first
/// ordering as before this existed. Currently-boosted offers among
/// themselves also sort nearest-first, not by boost recency/duration —
/// there's no "who paid more" ranking here, just "boosted or not".
List<OfferWithDistance> _sortBoostedFirst(List<OfferWithDistance> offers) {
  final result = [...offers];
  result.sort((a, b) {
    if (a.offer.isBoosted != b.offer.isBoosted) {
      return a.offer.isBoosted ? -1 : 1;
    }
    return a.distanceMeters.compareTo(b.distanceMeters);
  });
  return result;
}

/// Backs Kəşf et → Təkliflər — reuses the EXACT same radius system as
/// İnsanlar/Məkanlar ([selectedDiscoverModeProvider]) per the product
/// spec, plus the Filter bottom sheet's category selection. One-shot
/// fetch, not a live stream, same reasoning as `nearbyVenuesProvider`.
final nearbyOffersProvider = FutureProvider.autoDispose<List<OfferWithDistance>>((ref) async {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  final category = ref.watch(selectedOfferCategoryFilterProvider);
  final repository = ref.watch(offerRepositoryProvider);

  if (position == null) return const [];

  List<OfferWithDistance> result;
  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      result = await repository.fetchOffersWithinRadius(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: selection.km!,
        category: category,
      );
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(profileControllerProvider.select((p) => p.country));
      if (myCountry == null) return const [];
      final offers = await repository.fetchOffersByCountry(myCountry, category: category);
      result = _withDistanceFrom(offers, position);
    case DiscoverRadiusMode.world:
      final offers = await repository.fetchAllActiveOffers(category: category);
      result = _withDistanceFrom(offers, position);
  }

  // `OfferType.birthday` offers are never for "everyone" — only the
  // specific uids in `targetUserIds` (the matched birthday users) may
  // ever see one here, same as every other offer type is otherwise
  // open to. A direct link (the target user's own "your offer is
  // ready" push, see `onOfferUpdated`'s birthday-approval branch in
  // functions/src/index.ts) still reaches `OfferDetailsScreen` fine —
  // this filter only ever touches the "everyone" list providers, never
  // a single-doc fetch by id.
  final myUid = _currentUid();
  result = result
      .where((r) => r.offer.offerType != OfferType.birthday || (myUid != null && r.offer.targetUserIds.contains(myUid)))
      .toList();

  return _sortBoostedFirst(result);
});
