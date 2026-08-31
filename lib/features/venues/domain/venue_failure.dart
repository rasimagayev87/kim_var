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

  /// `invalid-argument` — the photo URL was refused. In practice this
  /// means the upload did not finish, or produced a URL outside our
  /// own Storage bucket.
  photoRejected,

  /// `permission-denied` from `assertActiveUser` — deleted or banned.
  accountBlocked,

  /// `already-exists` — this venue id was already submitted.
  duplicate,

  /// Anything else, including network failures.
  unknown,
}

/// Maps a `FirebaseFunctionsException.code` (plus its message, where
/// one code covers two cases) onto [VenueSubmitError].
VenueSubmitError venueSubmitErrorFromCode(String? code, String? message) {
  switch (code) {
    case 'resource-exhausted':
      return VenueSubmitError.rateLimited;
    case 'already-exists':
      return VenueSubmitError.duplicate;
    case 'invalid-argument':
      return VenueSubmitError.photoRejected;
    case 'failed-precondition':
      return VenueSubmitError.offerNotAccepted;
    case 'permission-denied':
      // `assertActiveUser` sends `account-deleted`/`account-banned` as
      // the message; the business-activity refusal is the other user
      // of this code and is the far more common one.
      final m = message ?? '';
      return m.contains('account-deleted') || m.contains('account-banned')
          ? VenueSubmitError.accountBlocked
          : VenueSubmitError.businessInactive;
    default:
      return VenueSubmitError.unknown;
  }
}
