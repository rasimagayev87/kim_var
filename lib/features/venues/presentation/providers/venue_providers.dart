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

export '../../domain/repositories/venue_repository.dart' show VenueWithDistance, SubmitVenueResult;

/// Exposed as its own provider (rather than left as a private default
/// inside [FirebaseVenueRepository]'s constructor) so the Riverpod
/// dependency graph is explicit end to end, and a future widget/unit
/// test can override just this one node with a fake datasource
/// without touching the repository or anything above it.
final venueRemoteDatasourceProvider = Provider<VenueRemoteDatasource>(
  (ref) => FirebaseVenueRemoteDatasource(),
);

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  return FirebaseVenueRepository(
    datasource: ref.watch(venueRemoteDatasourceProvider),
  );
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

  /// Returns the new venue + its required Epoint checkout on success,
  /// null on failure — [onValidationError] receives exactly which
  /// fields are missing so the form can highlight them, [onError]
  /// covers anything else. Every venue's first cycle is a real charge,
  /// founding or not — see `SubmitVenueResult`'s own doc comment.
  Future<SubmitVenueResult?> createVenue({
    required String name,
    required VenueCategory? category,
    required File? photo,
    required double? lat,
    required double? lng,
    required String address,
    String? country,
    required OpeningHours openingHours,
    VenueSocialLinks? socialLinks,
    String audienceRadiusMode = 'distance',
    double audienceRadiusKm = 1.0,
    bool birthdayNotificationsEnabled = false,
    required String offerAcceptanceVersion,
    required String offerAcceptanceDocumentUrl,
    required String offerAcceptanceAppVersion,
    required void Function(List<VenueFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final result = await _ref
          .read(createVenueUseCaseProvider)
          .call(
            ownerId: uid,
            name: name,
            category: category,
            photo: photo,
            lat: lat,
            lng: lng,
            address: address,
            country: country,
            openingHours: openingHours,
            socialLinks: socialLinks,
            audienceRadiusMode: audienceRadiusMode,
            audienceRadiusKm: audienceRadiusKm,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            offerAcceptanceVersion: offerAcceptanceVersion,
            offerAcceptanceDocumentUrl: offerAcceptanceDocumentUrl,
            offerAcceptanceAppVersion: offerAcceptanceAppVersion,
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
      return result;
    } on VenueValidationException catch (e) {
      onValidationError(e.missingFields);
      return null;
    } catch (e, st) {
      logError('venue_providers.createVenue', e, st);
      onError();
      return null;
    }
  }

  /// [sentForReReview] reflects the `updateVenue` Cloud Function's own
  /// diff-based decision (see its doc comment) — false for a
  /// radius-only edit or a venue that wasn't live yet, so callers can
  /// tell whether to show a "sent back for review" notice.
  Future<({bool success, bool sentForReReview})> updateVenue({
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
    VenueSocialLinks? socialLinks,
    String audienceRadiusMode = 'distance',
    double audienceRadiusKm = 1.0,
    bool birthdayNotificationsEnabled = false,
    required void Function(List<VenueFieldError> missing) onValidationError,
    required void Function() onError,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    try {
      final sentForReReview = await _ref
          .read(updateVenueUseCaseProvider)
          .call(
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
            socialLinks: socialLinks,
            audienceRadiusMode: audienceRadiusMode,
            audienceRadiusKm: audienceRadiusKm,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
      _ref.invalidate(nearbyVenuesProvider);
      return (success: true, sentForReReview: sentForReReview);
    } on VenueValidationException catch (e) {
      onValidationError(e.missingFields);
      return (success: false, sentForReReview: false);
    } catch (e, st) {
      logError('venue_providers.updateVenue', e, st);
      onError();
      return (success: false, sentForReReview: false);
    }
  }

  Future<bool> deleteVenue(
    String venueId, {
    required void Function() onError,
  }) async {
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

  /// Flips [venueId]'s like state for the signed-in user. No-op
  /// (returns false) when signed out — the calling UI is expected to
  /// already be gated by the same auth check every other write in this
  /// app uses.
  Future<bool> toggleLike(
    String venueId, {
    required bool isCurrentlyLiked,
  }) async {
    final uid = _currentUid();
    if (uid == null) return false;

    try {
      await _ref
          .read(venueRepositoryProvider)
          .setLiked(uid: uid, venueId: venueId, isLiked: !isCurrentlyLiked);
      return true;
    } catch (e, st) {
      logError('venue_providers.toggleLike', e, st);
      return false;
    }
  }

  /// Flips [venue]'s check-in state for the signed-in user.
  ///
  /// Checking OUT is always allowed from anywhere (no GPS gate — a
  /// gate only makes sense on the way in). Checking IN requires the
  /// device to be within [_checkinRadiusMeters] of the venue, verified
  /// here with the same `Geolocator.distanceBetween` math the Məkanlar
  /// list already uses for sorting — GPS spoofing can't be fully
  /// stopped client-side, so this is a UX/product gate, not a security
  /// boundary (firestore.rules only enforces "own doc only").
  static const _checkinRadiusMeters = 150.0;

  Future<CheckinToggleResult> toggleCheckin(
    Venue venue, {
    required bool isCurrentlyCheckedInHere,
  }) async {
    final uid = _currentUid();
    if (uid == null) return CheckinToggleResult.notSignedIn;

    try {
      if (isCurrentlyCheckedInHere) {
        await _ref.read(venueRepositoryProvider).checkOut(uid: uid);
        return CheckinToggleResult.success;
      }

      final position = _ref.read(locationControllerProvider).valueOrNull;
      if (position == null) return CheckinToggleResult.locationUnavailable;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        venue.lat,
        venue.lng,
      );
      if (distance > _checkinRadiusMeters) return CheckinToggleResult.tooFar;

      await _ref
          .read(venueRepositoryProvider)
          .checkIn(uid: uid, venueId: venue.id);
      return CheckinToggleResult.success;
    } catch (e, st) {
      logError('venue_providers.toggleCheckin', e, st);
      return CheckinToggleResult.error;
    }
  }

  /// Called right after a successful [updateVenue] on a
  /// `needs_revision` venue — moves it back to `pending` via the
  /// `resubmitVenue` Cloud Function (the only client path there, see
  /// firestore.rules). Returns false on any failure; the caller
  /// already saved the edited fields either way, so a resubmit failure
  /// here is "your edit saved but wasn't resubmitted yet, try again"
  /// rather than a lost edit.
  Future<bool> resubmitVenue(String venueId) async {
    try {
      await _ref.read(venueRepositoryProvider).resubmitVenue(venueId);
      return true;
    } catch (e, st) {
      logError('venue_providers.resubmitVenue', e, st);
      return false;
    }
  }

  /// "Məkanı premium et" — the owner-only premium checkout on Discover
  /// → Məkanlar (see `_openVenuePremiumMenu` in `discover_tab.dart`).
  /// No client-side ownership re-check here; the UI only ever exposes
  /// this control to the venue's own owner in the first place. Doesn't
  /// set anything itself — `Venue.isPremium`/`premiumExpiresAt` only
  /// move once `epointWebhook` confirms the charge.
  Future<({String checkoutUrl, double feeAmount, String paymentId})?> createVenuePremiumCheckout(String venueId, int months) async {
    try {
      return await _ref.read(venueRepositoryProvider).createVenuePremiumCheckout(venueId, months);
    } catch (e, st) {
      logError('venue_providers.createVenuePremiumCheckout', e, st);
      return null;
    }
  }

  /// "Boş yer sayı" quick-edit sheet's Save action — see
  /// `VenueRepository.updateAvailableSeats`'s doc comment for why this
  /// is a standalone write, separate from [updateVenue].
  Future<bool> updateAvailableSeats({required String venueId, required int availableSeats}) async {
    try {
      await _ref.read(venueRepositoryProvider).updateAvailableSeats(venueId: venueId, availableSeats: availableSeats);
      return true;
    } catch (e, st) {
      logError('venue_providers.updateAvailableSeats', e, st);
      return false;
    }
  }
}

enum CheckinToggleResult {
  success,
  tooFar,
  locationUnavailable,
  notSignedIn,
  error,
}

final venueControllerProvider = Provider<VenueController>(
  (ref) => VenueController(ref),
);

/// Whether the signed-in user has liked this one venue — a per-item
/// `.family` watch (mirrors `isPostLikedByMeProvider`) rather than one
/// big set, since `likes` now lives under each venue doc instead of
/// centralized under the user.
final isVenueLikedByMeProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, venueId) {
      final uid = _currentUid();
      if (uid == null) return Stream.value(false);
      return ref.watch(venueRepositoryProvider).watchIsLikedByMe(venueId, uid);
    });

/// Live "Hazırda N istifadəçi buradadır" count on the venue profile.
final venueActiveCheckinCountProvider = StreamProvider.autoDispose
    .family<int, String>((ref, venueId) {
      return ref
          .watch(venueRepositoryProvider)
          .watchActiveCheckinCount(venueId);
    });

/// Whether the signed-in user is checked in at THIS venue specifically.
final isCheckedInHereProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, venueId) {
    final uid = _currentUid();
    if (uid == null) return Stream.value(false);
    return ref
        .watch(venueRepositoryProvider)
        .watchIsCheckedInHere(venueId, uid);
  },
);

/// Wraps active venues with real Haversine distance from [position],
/// sorted nearest-first — used for the Ölkə/Dünya modes, which don't
/// go through GeoFlutterFire Plus (no radius to bound them by) but
/// still need a distance to show and a sensible sort order.
List<VenueWithDistance> _withDistanceFrom(
  List<Venue> venues,
  Position position,
) {
  final result = venues
      .map(
        (venue) => (
          venue: venue,
          distanceMeters: Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            venue.lat,
            venue.lng,
          ),
        ),
      )
      .toList();
  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return result;
}

/// The Filter bottom sheet's selected category — null means "every
/// category". Mirrors `selectedOfferCategoryFilterProvider`.
final selectedVenueCategoryFilterProvider = StateProvider<VenueCategory?>(
  (ref) => null,
);

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
///
/// The radius/mode filter always runs first and is never widened —
/// sorting only reorders the venues already inside it (premium first;
/// among multiple premium venues, an equal-weight random rotation that
/// reshuffles every 5 minutes, see [_premiumRotationHash]; non-premium
/// venues sort by highest-rated, distance as the final tie-breaker),
/// it never pulls in anything from outside the selected radius. This is a
/// deliberate product policy: users must never see results sorted
/// past what they chose.
final nearbyVenuesProvider =
    FutureProvider.autoDispose<List<VenueWithDistance>>((ref) async {
      final position = ref.watch(locationControllerProvider).valueOrNull;
      final selection = ref.watch(selectedDiscoverModeProvider);
      final category = ref.watch(selectedVenueCategoryFilterProvider);
      final repository = ref.watch(venueRepositoryProvider);

      if (position == null) return const [];

      final result = switch (selection.mode) {
        DiscoverRadiusMode.distance => await repository.fetchVenuesWithinRadius(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: selection.km!,
          category: category,
        ),
        DiscoverRadiusMode.country => await () async {
          final myCountry = ref.watch(
            profileControllerProvider.select((p) => p.country),
          );
          if (myCountry == null) return <VenueWithDistance>[];
          final venues = await repository.fetchVenuesByCountry(
            myCountry,
            category: category,
          );
          return _withDistanceFrom(venues, position);
        }(),
        DiscoverRadiusMode.world => await () async {
          final venues = await repository.fetchAllActiveVenues(
            category: category,
          );
          return _withDistanceFrom(venues, position);
        }(),
      };

      final epochBucket = (DateTime.now().millisecondsSinceEpoch / (5 * 60 * 1000)).floor();
      final sorted = [...result]
        ..sort((a, b) {
          final byPremium = (b.venue.isPremium ? 1 : 0).compareTo(
            a.venue.isPremium ? 1 : 0,
          );
          if (byPremium != 0) return byPremium;
          if (a.venue.isPremium && b.venue.isPremium) {
            final byRotation = _premiumRotationHash(
              b.venue.id,
              epochBucket,
            ).compareTo(_premiumRotationHash(a.venue.id, epochBucket));
            return byRotation != 0
                ? byRotation
                : a.distanceMeters.compareTo(b.distanceMeters);
          }
          final byRating = b.venue.rating.compareTo(a.venue.rating);
          return byRating != 0
              ? byRating
              : a.distanceMeters.compareTo(b.distanceMeters);
        });
      return sorted;
    });

/// Cheap deterministic hash combining a 5-minute epoch bucket with a
/// venue id — used ONLY to rotate ordering among simultaneously
/// premium venues (equal-weight lottery, not weighted by payment
/// amount/tier — see [nearbyVenuesProvider]'s own doc comment). Every
/// device computes the same bucket from wall-clock time, so ordering
/// is consistent across viewers within the same 5-minute window
/// without any server call or stored doc — plain FNV-1a, good enough
/// distribution for this, no crypto needed. The next window's order is
/// unknowable ahead of time since it depends on a bucket number that
/// hasn't happened yet.
int _premiumRotationHash(String venueId, int epochBucket) {
  final input = '$epochBucket:$venueId';
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
