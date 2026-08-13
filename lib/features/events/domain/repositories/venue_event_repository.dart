import 'dart:io';

import 'package:flutter/foundation.dart';

import '../entities/venue_event.dart';

/// Same distance-pairing convention as `OfferWithDistance`/`VenueWithDistance`.
typedef VenueEventWithDistance = ({VenueEvent event, double distanceMeters});

abstract class VenueEventRepository {
  /// Auto-approved — the returned event is immediately `upcoming` and
  /// visible; see [VenueEvent]'s doc comment for why no moderation gate
  /// applies here the way it does for [Venue]/`Offer`. The
  /// `notifyNearbyUsersOfNewEvent` Cloud Function trigger (reacting to
  /// this doc's creation) handles the radius push fanout — nothing
  /// client-side calls it directly.
  Future<String> createEvent({
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
  });

  Future<void> cancelEvent(String eventId);

  /// Realtime single-event lookup — backs `EventDetailsScreen`, same
  /// reasoning as `venueByIdProvider`/`offerByIdProvider`.
  Stream<VenueEvent?> watchEvent(String eventId);

  /// Owner's own "Tədbirlər" list — every event this venue has ever
  /// published, any status, newest first.
  Stream<List<VenueEvent>> watchEventsByVenue(String venueId);

  /// One-shot (not realtime — a banner doesn't need millisecond-live
  /// updates, same reasoning as `fetchVenuesWithinRadius`) lookup of
  /// this venue's upcoming/live event happening today, if any — powers
  /// the "🎤 Bu axşam" banner on Discover venue cards. Null when there
  /// isn't one.
  Future<VenueEvent?> fetchTodayEventForVenue(String venueId);

  /// Kəşf et → Təkliflər → "Tədbir" filter — every upcoming/live event
  /// within [radiusKm] of ([lat], [lng]), same one-shot-fetch
  /// reasoning as `VenueRepository.fetchVenuesWithinRadius`.
  Future<List<VenueEventWithDistance>> fetchEventsWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
  });

  /// Writes an `eventReports/{reportId}` doc — write-only from the
  /// client (see firestore.rules), resolved later from the admin
  /// panel's "Tədbir şikayətləri" section via the Admin SDK.
  Future<void> reportEvent({required String eventId, required String reportedBy, required String reason});
}
