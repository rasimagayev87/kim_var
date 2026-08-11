import 'dart:io';

import 'package:flutter/foundation.dart';

import '../entities/venue.dart';

/// A venue paired with its distance from the point a query was
/// centered on, in metres — real Haversine/geohash-derived distance,
/// never a fabricated number.
typedef VenueWithDistance = ({Venue venue, double distanceMeters});

abstract class VenueRepository {
  /// [onUploadProgress] and [onUploadTaskReady] only ever fire while
  /// the photo itself is uploading — see
  /// `VenueRemoteDatasource.uploadVenuePhoto` for the exact contract
  /// (progress as a 0.0–1.0 fraction, task-ready handing back a
  /// cancel function).
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
    String audienceRadiusMode,
    double audienceRadiusKm,
    bool birthdayNotificationsEnabled,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

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
    String audienceRadiusMode,
    double audienceRadiusKm,
    bool birthdayNotificationsEnabled,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  Future<void> deleteVenue(String venueId);

  Stream<Venue?> watchVenue(String venueId);

  /// "Mənim məkanlarım" — every venue this uid submitted, regardless of
  /// distance from them right now.
  Stream<List<Venue>> watchMyVenues(String ownerId);

  /// One-shot fetch (via GeoFlutterFire Plus) of every active venue
  /// within [radiusKm] of ([lat], [lng]), sorted nearest-first. Not a
  /// realtime listener on purpose: a venue directory doesn't need
  /// millisecond-live updates the way chat does, and merging several
  /// parallel live listeners for one screen would be a lot of standing
  /// complexity for no real benefit.
  Future<List<VenueWithDistance>> fetchVenuesWithinRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    VenueCategory? category,
  });

  /// Backs "Ölkə üzrə" — every active venue whose reverse-geocoded
  /// [Venue.country] matches the viewer's own profile country.
  Future<List<Venue>> fetchVenuesByCountry(
    String country, {
    VenueCategory? category,
  });

  /// Backs "Dünya üzrə" — every active venue, no geo filtering at all.
  Future<List<Venue>> fetchAllActiveVenues({
    int limit,
    VenueCategory? category,
  });

  /// Whether [uid] has liked [venueId] — see `Venue.likeCount`.
  Stream<bool> watchIsLikedByMe(String venueId, String uid);

  /// Toggles a like. Only writes the `likes/{uid}` doc — `likeCount`/
  /// `rating` are updated server-side by a Cloud Function trigger.
  Future<void> setLiked({
    required String uid,
    required String venueId,
    required bool isLiked,
  });

  /// Live "how many PeakPin users are here right now" count for the
  /// venue profile screen.
  Stream<int> watchActiveCheckinCount(String venueId);

  /// Whether [uid] is currently checked in at [venueId] specifically.
  Stream<bool> watchIsCheckedInHere(String venueId, String uid);

  /// Moves [uid]'s single active check-in to [venueId] — does NOT
  /// verify GPS proximity itself, callers must do that first (see
  /// `VenueController.toggleCheckin`).
  Future<void> checkIn({required String uid, required String venueId});

  Future<void> checkOut({required String uid});

  /// Moves a `needs_revision` venue back to `pending` after the owner
  /// has edited it — the only client path back to `pending` (see
  /// firestore.rules), via the `resubmitVenue` Cloud Function. Throws
  /// on any failure (not-owner, wrong status, network) — callers show
  /// a generic error, same convention as everywhere else in this app.
  Future<void> resubmitVenue(String venueId);
}
