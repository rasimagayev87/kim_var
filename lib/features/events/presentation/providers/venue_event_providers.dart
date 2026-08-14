import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../venues/domain/entities/venue.dart' show VenueCategory;
import '../../data/repositories/firebase_venue_event_repository.dart';
import '../../domain/entities/venue_event.dart';
import '../../domain/repositories/venue_event_repository.dart';

final venueEventRepositoryProvider = Provider<VenueEventRepository>((ref) => FirebaseVenueEventRepository());

/// Which venue categories may publish events at all — read from
/// `config/eventCategories.enabledCategories` (see
/// `admin-panel/scripts/set-event-categories.ts`), NOT a hardcoded Dart
/// constant, so it can change without a client release (deliberately
/// different from `kBirthdayEligibleVenueCategories`, which IS
/// hardcoded — that one predates this config-doc pattern). Fails
/// closed: any read error or a missing/malformed doc resolves to an
/// empty set, so a config problem hides the create-event entry point
/// rather than opening it to every category.
final eventCategoryConfigProvider = FutureProvider<Set<VenueCategory>>((ref) async {
  try {
    final snap = await FirebaseFirestore.instance.collection('config').doc('eventCategories').get();
    final raw = (snap.data()?['enabledCategories'] as List?)?.cast<String>() ?? const [];
    return raw.map((name) => VenueCategory.values.where((c) => c.name == name)).expand((it) => it).toSet();
  } catch (e, st) {
    logError('venue_event_providers.eventCategoryConfigProvider', e, st);
    return const {};
  }
});

/// Realtime single-event lookup — backs `EventDetailsScreen`.
final venueEventByIdProvider = StreamProvider.autoDispose.family<VenueEvent?, String>((ref, eventId) {
  return ref.watch(venueEventRepositoryProvider).watchEvent(eventId);
});

/// Owner's own "Tədbirlər" list on the venue management screen.
final venueEventsByVenueProvider = StreamProvider.autoDispose.family<List<VenueEvent>, String>((ref, venueId) {
  return ref.watch(venueEventRepositoryProvider).watchEventsByVenue(venueId);
});

/// "🎤 Bu axşam" banner lookup for one Discover venue card — a
/// per-card `FutureProvider.family`, same established pattern as
/// `isVenueLikedByMeProvider`/`venueActiveCheckinCountProvider` already
/// use for other per-card state on the same list.
final venueTodayEventProvider = FutureProvider.autoDispose.family<VenueEvent?, String>((ref, venueId) {
  return ref.watch(venueEventRepositoryProvider).fetchTodayEventForVenue(venueId);
});

/// Kəşf et → Təkliflər → "Tədbir" filter — reuses [locationControllerProvider]
/// for the viewer's own position, same as `nearbyOffersProvider`.
/// Distance-radius mode only: an event is inherently local/time-bound
/// (a "bu axşam" happening doesn't make sense at a country/world
/// scale the way an evergreen discount does), so country/world
/// Discover modes simply show no events — Kompaniya offers still work
/// normally in those modes.
final nearbyEventsProvider = FutureProvider.autoDispose<List<VenueEventWithDistance>>((ref) async {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  if (position == null || selection.mode != DiscoverRadiusMode.distance || selection.km == null) return const [];

  return ref.watch(venueEventRepositoryProvider).fetchEventsWithinRadius(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: selection.km!,
      );
});

class VenueEventController {
  VenueEventController(this._ref);

  final Ref _ref;

  Future<String?> createEvent({
    required String venueId,
    required String venueName,
    String? venuePhotoUrl,
    required double lat,
    required double lng,
    required String title,
    required String description,
    File? coverImage,
    required DateTime startAt,
    required DateTime endAt,
    required VenueEventCategory category,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  }) async {
    try {
      return await _ref.read(venueEventRepositoryProvider).createEvent(
            venueId: venueId,
            venueName: venueName,
            venuePhotoUrl: venuePhotoUrl,
            lat: lat,
            lng: lng,
            title: title,
            description: description,
            coverImage: coverImage,
            startAt: startAt,
            endAt: endAt,
            category: category,
            onUploadProgress: onUploadProgress,
            onUploadTaskReady: onUploadTaskReady,
          );
    } catch (e, st) {
      logError('venue_event_providers.createEvent', e, st);
      return null;
    }
  }

  Future<bool> reportEvent({required String eventId, required String reportedBy, required String reason}) async {
    try {
      await _ref.read(venueEventRepositoryProvider).reportEvent(eventId: eventId, reportedBy: reportedBy, reason: reason);
      return true;
    } catch (e, st) {
      logError('venue_event_providers.reportEvent', e, st);
      return false;
    }
  }

  Future<bool> cancelEvent(String eventId) async {
    try {
      await _ref.read(venueEventRepositoryProvider).cancelEvent(eventId);
      return true;
    } catch (e, st) {
      logError('venue_event_providers.cancelEvent', e, st);
      return false;
    }
  }
}

final venueEventControllerProvider = Provider<VenueEventController>((ref) => VenueEventController(ref));
