import 'dart:io';

import 'package:flutter/foundation.dart';

import '../entities/venue.dart';

/// A venue paired with its distance from the point a query was
/// centered on, in metres — real Haversine/geohash-derived distance,
/// never a fabricated number.
typedef VenueWithDistance = ({Venue venue, double distanceMeters});

/// [venueId] identifies the newly-created (still `awaiting_payment`)
/// venue — invisible to everyone, including the moderation queue, until
/// the owner completes checkout ([paymentId] identifies which
/// `payments` doc — pass it, along with [checkoutUrl]/[feeAmount], to
/// `presentEpointCheckout` (lib/core/payments/epoint_checkout.dart))
/// and `epointWebhook` (functions/src/index.ts) confirms the charge.
/// Unlike offers, there's no free-quota exception here — every venue's
/// first cycle is always a real charge, founding or not (see
/// `submitVenue`'s own doc comment).
typedef SubmitVenueResult = ({
  String venueId,
  String checkoutUrl,
  double feeAmount,
  String paymentId,
});

abstract class VenueRepository {
  /// [onUploadProgress] and [onUploadTaskReady] only ever fire while
  /// the photo itself is uploading — see
  /// `VenueRemoteDatasource.uploadVenuePhoto` for the exact contract
  /// (progress as a 0.0–1.0 fraction, task-ready handing back a
  /// cancel function).
  Future<SubmitVenueResult> createVenue({
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
    required String offerAcceptanceVersion,
    required String offerAcceptanceDocumentUrl,
    required String offerAcceptanceAppVersion,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<VoidCallback>? onUploadTaskReady,
  });

  /// Edits an existing venue via the `updateVenue` Cloud Function
  /// (moved server-side so the "does this edit need re-review" diff
  /// can't be bypassed by a modified client — see that function's own
  /// doc comment, functions/src/index.ts). Returns whether the edit
  /// sent the venue back into moderation: true for any changed field
  /// other than [audienceRadiusMode]/[audienceRadiusKm] on a venue that
  /// was `needs_revision`/`approved`; false for a radius-only edit
  /// (applies immediately, no re-review) or a venue that wasn't live
  /// yet in the first place.
  Future<bool> updateVenue({
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

  /// Re-opens (or creates, if `renewVenueSubscriptions` hasn't caught
  /// up to this venue yet) an Epoint checkout for the current overdue
  /// subscription cycle — backs the "Ödə" button on `MyVenuesScreen`'s
  /// overdue banner. Throws if the venue isn't actually overdue yet
  /// (see `retryVenueSubscriptionPayment`, functions/src/index.ts).
  ///
  /// [offerAcceptance] is only passed when the caller detected the
  /// venue's stored `offerAcceptedVersion` no longer matches the
  /// current `AppConfig.businessOfferVersion` and the owner re-accepted
  /// via `showBusinessOfferReacceptSheet` — omitted otherwise, in which
  /// case the Cloud Function proceeds using the existing acceptance on
  /// file (see that function's own doc comment for the backward-compat
  /// case of a venue with no acceptance at all).
  Future<({String checkoutUrl, double feeAmount, String paymentId})> retryVenueSubscriptionPayment(
    String venueId, {
    ({String version, String documentUrl, String appVersion})? offerAcceptance,
  });

  /// Re-opens a checkout for a brand new venue's FIRST subscription
  /// payment, still `awaiting_payment` because the owner abandoned or a
  /// previous Epoint attempt failed — backs `MyVenuesScreen`'s
  /// first-payment banner. Distinct from [retryVenueSubscriptionPayment],
  /// which only handles an already-live venue's overdue renewal (see
  /// `retryVenueCreationPayment`, functions/src/index.ts).
  Future<({String checkoutUrl, double feeAmount, String paymentId})> retryVenueCreationPayment(String venueId);

  /// Starts an Epoint checkout for one of the 1/6/12-month "Məkanı
  /// premium et" tiers. `Venue.isPremium`/`premiumSince`/
  /// `premiumExpiresAt` are set only by `applyPaymentOutcome`'s
  /// `venue_premium` branch (functions/src/index.ts) once the charge
  /// is confirmed — never directly from here (see firestore.rules'
  /// venues update rule).
  Future<({String checkoutUrl, double feeAmount, String paymentId})> createVenuePremiumCheckout(String venueId, int months);

  /// Clears [Venue.firstPaymentAnnouncementPending] once the owner has
  /// seen/dismissed the first-payment confirmation card — a plain,
  /// unrestricted owner field (not grant-of-trust, see firestore.rules),
  /// same "lightweight single-field write" shape as [updateAvailableSeats].
  Future<void> dismissFirstPaymentAnnouncement(String venueId);

  /// Standalone write for [Venue.availableSeats] — deliberately NOT
  /// part of [updateVenue]'s full edit flow, since this is meant for
  /// frequent, lightweight updates from a quick stepper sheet, not a
  /// full form resubmit. Always stamps [Venue.seatsUpdatedAt] to now.
  Future<void> updateAvailableSeats({
    required String venueId,
    required int availableSeats,
  });
}
