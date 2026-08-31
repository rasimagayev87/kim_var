/// One entry per missing/invalid required field — lets the form tell
/// the user exactly what's not filled in, rather than one generic
/// "fill out the form" message. Mirrors `EventFieldError`'s role in
/// the events feature.
enum VenueFieldError { photo, name, category, location, hours }

class VenueValidationException implements Exception {
  final List<VenueFieldError> missingFields;
  const VenueValidationException(this.missingFields);
}

/// Why a venue submission was refused by the server.
///
/// The form used to collapse every server-side refusal into one
/// "operation failed, try again later" message. That message is wrong
/// for most of the reasons it was shown for: "try again later" does
/// nothing about an unaccepted offer or a business account that is
/// switched off, and it sends the user back into the same failing flow
/// with no idea what to change.
///
/// Mapped from the Cloud Function's own `HttpsError` codes — see
/// `submitVenue` in `functions/src/index.ts`, whose refusals now log a
/// matching `reason` slug server-side.
enum VenueSubmitError {
  /// `resource-exhausted` — a rate limit was hit.
  rateLimited,

  /// `permission-denied` with business activity switched off.
  businessInactive,

  /// `failed-precondition` — the public offer was not accepted.
  offerNotAccepted,

  /// The photo URL was refused — the upload did not finish, or
  /// produced a URL outside our own Storage bucket.
  photoRejected,

  /// A required field arrived empty. In practice this is the address:
  /// reverse geocoding can return nothing, and the form does not show
  /// the address as its own field, so there is nothing obviously blank
  /// to notice.
  missingFields,

  /// `permission-denied` from `assertActiveUser` — deleted or banned.
  accountBlocked,

  /// `already-exists` — this venue id was already submitted.
  duplicate,

  /// Anything else, including network failures.
  unknown,
}

/// Maps a `FirebaseFunctionsException` onto [VenueSubmitError].
///
/// Prefers `details.reason` — the exact slug `submitVenue` logs — over
/// the error code. Codes are too coarse to map safely on their own:
/// `invalid-argument` covers both "a required field is empty" and
/// "that photo URL is not ours", and an earlier version of this
/// function assumed the second. It was the first, so the app told
/// someone their photo was rejected while the actual problem was an
/// address the geocoder never filled in — sending them to change the
/// one thing that was fine.
///
/// The code path below stays as a fallback for a client talking to a
/// server that predates `details`.
VenueSubmitError venueSubmitErrorFromException(
  String? code,
  String? message,
  Object? details,
) {
  final reason = (details is Map) ? details['reason'] as String? : null;
  switch (reason) {
    case 'submitVenue.missing-fields':
      return VenueSubmitError.missingFields;
    case 'submitVenue.foreign-photo-url':
      return VenueSubmitError.photoRejected;
    case 'submitVenue.offer-not-accepted':
      return VenueSubmitError.offerNotAccepted;
    case 'submitVenue.business-inactive':
      return VenueSubmitError.businessInactive;
    case 'submitVenue.duplicate-id':
      return VenueSubmitError.duplicate;
  }

  switch (code) {
    case 'resource-exhausted':
      return VenueSubmitError.rateLimited;
    case 'already-exists':
      return VenueSubmitError.duplicate;
    case 'invalid-argument':
      // Deliberately NOT `photoRejected` — see above. Without a
      // `reason` there is no way to tell which field is at fault, and
      // naming the wrong one is worse than admitting we do not know.
      return VenueSubmitError.missingFields;
    case 'failed-precondition':
      return VenueSubmitError.offerNotAccepted;
    case 'permission-denied':
      final m = message ?? '';
      return m.contains('account-deleted') || m.contains('account-banned')
          ? VenueSubmitError.accountBlocked
          : VenueSubmitError.businessInactive;
    default:
      return VenueSubmitError.unknown;
  }
}
