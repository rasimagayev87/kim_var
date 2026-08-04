import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/firebase_venue_remote_datasource.dart';
import '../../data/datasources/venue_remote_datasource.dart';
import '../../data/repositories/firebase_venue_repository.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../../domain/usecases/create_venue_usecase.dart';
import '../../domain/usecases/delete_venue_usecase.dart';
import '../../domain/usecases/update_venue_usecase.dart';
import '../../domain/venue_failure.dart';

export '../../domain/repositories/venue_repository.dart' show VenueWithDistance;

/// Exposed as its own provider (rather than left as a private default
/// inside [FirebaseVenueRepository]'s constructor) so the Riverpod
/// dependency graph is explicit end to end, and a future widget/unit
/// test can override just this one node with a fake datasource
/// without touching the repository or anything above it.
final venueRemoteDatasourceProvider = Provider<VenueRemoteDatasource>((ref) => FirebaseVenueRemoteDatasource());

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return FirebaseVenueRepository(datasource: ref.watch(venueRemoteDatasourceProvider));
});

final createVenueUseCaseProvider = Provider<CreateVenueUseCase>((ref) {
  return CreateVenueUseCase(ref.watch(venueRepositoryProvider));
});

final updateVenueUseCaseProvider = Provider<UpdateVenueUseCase>((ref) {
  return UpdateVenueUseCase(ref.watch(venueRepositoryProvider));
});

final deleteVenueUseCaseProvider = Provider<DeleteVenueUseCase>((ref) {
  return DeleteVenueUseCase(ref.watch(venueRepositoryProvider));
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final venueByIdProvider = StreamProvider.family<Venue?, String>((ref, venueId) {
  return ref.watch(venueRepositoryProvider).watchVenue(venueId);
});

/// "Mənim məkanlarım" — every venue the signed-in user submitted.
final myVenuesProvider = StreamProvider.autoDispose<List<Venue>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const []);
  return ref.watch(venueRepositoryProvider).watchMyVenues(uid);
});

/// Drives every venue write (create/update/delete). Same "log
/// internally, tell the caller a typed outcome" contract as
/// `EventController`/`ChatController` elsewhere in this app.
class VenueController {
  VenueController(this._ref);

  final Ref _ref;

  /// Returns the new venue's id on success, null on failure —
  /// [onValidationError] receives exactly which fields are missing so
  /// the form can highlight them, [onError] covers anything else.
  Future<String?> createVenue({
    required String name,
    required VenueCategory? category,
    required File? photo,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    required void Function(List<VenueFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final venueId = await _ref.read(createVenueUseCaseProvider).call(
            ownerId: uid,
            name: name,
            category: category,
            photo: photo,
            lat: lat,
            lng: lng,
            address: address,
            country: country,
            openingHours: openingHours,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      // nearbyVenuesProvider is a one-shot FutureProvider keyed off
      // position/radius, not the venues collection itself — creating a
      // venue doesn't change either of those, so without this the
      // Məkanlar list stays on its stale (pre-creation) result if
      // Discover tab never fully unmounted while the create form was
      // open on top of it (autoDispose only refetches on a fresh
      // watch, not on every write elsewhere).
      _ref.invalidate(nearbyVenuesProvider);
      return venueId;
    } on VenueValidationException catch (e) {
      onValidationError(e.missingFields);
      return null;
    } catch (e, st) {
      logError('venue_providers.createVenue', e, st);
      onError();
      return null;
    }
  }

  Future<bool> updateVenue({
    required String venueId,
    required String name,
    required VenueCategory? category,
    File? photo,
    required bool hasExistingPhoto,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    required void Function(List<VenueFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    try {
      await _ref.read(updateVenueUseCaseProvider).call(
            venueId: venueId,
            name: name,
            category: category,
            photo: photo,
            hasExistingPhoto: hasExistingPhoto,
            lat: lat,
            lng: lng,
            address: address,
            country: country,
            openingHours: openingHours,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      _ref.invalidate(nearbyVenuesProvider);
      return true;
    } on VenueValidationException catch (e) {
      onValidationError(e.missingFields);
      return false;
    } catch (e, st) {
      logError('venue_providers.updateVenue', e, st);
      onError();
      return false;
    }
  }

  Future<bool> deleteVenue(String venueId, {required void Function() onError}) async {
    try {
      await _ref.read(deleteVenueUseCaseProvider).call(venueId);
      _ref.invalidate(nearbyVenuesProvider);
      return true;
    } catch (e, st) {
      logError('venue_providers.deleteVenue', e, st);
      onError();
      return false;
    }
  }

  /// Flips [venueId]'s favorite state for the signed-in user. No-op
  /// (returns false) when signed out — the calling UI is expected to
  /// already be gated by the same auth check every other write in this
  /// app uses.
  Future<bool> toggleFavorite(String venueId, {required bool isCurrentlyFavorite}) async {
    final uid = _currentUid();
    if (uid == null) return false;

    try {
      await _ref.read(venueRepositoryProvider).setFavorite(
            uid: uid,
            venueId: venueId,
            isFavorite: !isCurrentlyFavorite,
          );
      return true;
    } catch (e, st) {
      logError('venue_providers.toggleFavorite', e, st);
      return false;
    }
  }
}

final venueControllerProvider = Provider<VenueController>((ref) => VenueController(ref));

/// Realtime set of venue ids the signed-in user has favorited — drives
/// the filled-vs-outline heart state on both the list card and the
/// profile screen, mirroring the [blockedUserIdsProvider] pattern used
/// elsewhere in this app.
final favoriteVenueIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const {});
  return ref.watch(venueRepositoryProvider).watchFavoriteVenueIds(uid);
});

/// Wraps active venues with real Haversine distance from [position],
/// sorted nearest-first — used for the Ölkə/Dünya modes, which don't
/// go through GeoFlutterFire Plus (no radius to bound them by) but
/// still need a distance to show and a sensible sort order.
List<VenueWithDistance> _withDistanceFrom(List<Venue> venues, Position position) {
  final result = venues
      .map(
        (venue) => (
          venue: venue,
          distanceMeters: Geolocator.distanceBetween(position.latitude, position.longitude, venue.lat, venue.lng),
        ),
      )
      .toList();
  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return result;
}

/// The Filter bottom sheet's selected category — null means "every
/// category". Mirrors `selectedOfferCategoryFilterProvider`.
final selectedVenueCategoryFilterProvider = StateProvider<VenueCategory?>((ref) => null);

/// Backs the Kəşf et → Məkanlar list — reuses the EXACT same radius
/// system as İnsanlar ([selectedDiscoverModeProvider]/[locationControllerProvider])
/// per the product spec, so switching between the two tabs never
/// feels like a different filter. One-shot fetch (not a live stream —
/// see [VenueRepository.fetchVenuesWithinRadius]), recomputed whenever
/// the device position, selected radius mode, or selected category
/// changes. The distance mode delegates all geohash-cell/precision
/// math to GeoFlutterFire Plus; country/world modes have no radius to
/// bound them by, so they stay plain Haversine-sorted queries like
/// before.
final nearbyVenuesProvider = FutureProvider.autoDispose<List<VenueWithDistance>>((ref) async {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  final category = ref.watch(selectedVenueCategoryFilterProvider);
  final repository = ref.watch(venueRepositoryProvider);

  if (position == null) return const [];

  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      return repository.fetchVenuesWithinRadius(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: selection.km!,
        category: category,
      );
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(profileControllerProvider.select((p) => p.country));
      if (myCountry == null) return const [];
      final venues = await repository.fetchVenuesByCountry(myCountry, category: category);
      return _withDistanceFrom(venues, position);
    case DiscoverRadiusMode.world:
      final venues = await repository.fetchAllActiveVenues(category: category);
      return _withDistanceFrom(venues, position);
  }
});
