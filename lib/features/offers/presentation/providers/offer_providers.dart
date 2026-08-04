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
  (ref, args) {
    return ref.watch(offerRepositoryProvider).fetchOtherActiveOffersForVenue(args.venueId, excludeOfferId: args.excludeOfferId);
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

  Future<String?> createOffer({
    required String? venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required String title,
    required String description,
    required VenueCategory? category,
    required OfferType? offerType,
    required double? discountValue,
    required DateTime? startDate,
    required DateTime? endDate,
    required File? photo,
    String? terms,
    String? contactPhone,
    bool showContactPhone = false,
    String? contactWebsite,
    bool showContactWebsite = false,
    String? contactInstagram,
    bool showContactInstagram = false,
    required void Function(List<OfferFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final offerId = await _ref.read(createOfferUseCaseProvider).call(
            ownerId: uid,
            venueId: venueId,
            venueName: venueName,
            venuePhotoUrl: venuePhotoUrl,
            lat: lat,
            lng: lng,
            address: address,
            country: country,
            title: title,
            description: description,
            category: category,
            offerType: offerType,
            discountValue: discountValue,
            startDate: startDate,
            endDate: endDate,
            photo: photo,
            terms: terms,
            contactPhone: contactPhone,
            showContactPhone: showContactPhone,
            contactWebsite: contactWebsite,
            showContactWebsite: showContactWebsite,
            contactInstagram: contactInstagram,
            showContactInstagram: showContactInstagram,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      // Same staleness gap as nearbyVenuesProvider — a one-shot
      // FutureProvider keyed off position/radius/category, not the
      // offers collection itself.
      _ref.invalidate(nearbyOffersProvider);
      return offerId;
    } on OfferValidationException catch (e) {
      onValidationError(e.missingFields);
      return null;
    } catch (e, st) {
      logError('offer_providers.createOffer', e, st);
      onError();
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
    String? contactPhone,
    bool showContactPhone = false,
    String? contactWebsite,
    bool showContactWebsite = false,
    String? contactInstagram,
    bool showContactInstagram = false,
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
            contactPhone: contactPhone,
            showContactPhone: showContactPhone,
            contactWebsite: contactWebsite,
            showContactWebsite: showContactWebsite,
            contactInstagram: contactInstagram,
            showContactInstagram: showContactInstagram,
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
}

final offerControllerProvider = Provider<OfferController>((ref) => OfferController(ref));

/// Realtime set of offer ids the signed-in user has favorited — mirrors
/// `favoriteVenueIdsProvider`.
final favoriteOfferIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const {});
  return ref.watch(offerRepositoryProvider).watchFavoriteOfferIds(uid);
});

/// Wraps active, non-expired offers with real Haversine distance from
/// [position], sorted nearest-first — mirrors
/// `venue_providers.dart`'s `_withDistanceFrom` for the Ölkə/Dünya
/// modes.
List<OfferWithDistance> _withDistanceFrom(List<Offer> offers, Position position) {
  final result = offers
      .map(
        (offer) => (
          offer: offer,
          distanceMeters: Geolocator.distanceBetween(position.latitude, position.longitude, offer.lat, offer.lng),
        ),
      )
      .toList();
  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
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

  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      return repository.fetchOffersWithinRadius(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: selection.km!,
        category: category,
      );
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(profileControllerProvider.select((p) => p.country));
      if (myCountry == null) return const [];
      final offers = await repository.fetchOffersByCountry(myCountry, category: category);
      return _withDistanceFrom(offers, position);
    case DiscoverRadiusMode.world:
      final offers = await repository.fetchAllActiveOffers(category: category);
      return _withDistanceFrom(offers, position);
  }
});
