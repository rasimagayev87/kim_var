import '../../../l10n/app_localizations.dart';
import '../domain/venue_listing_eligibility.dart';

/// Turns a [VenueListingBlock] into the sentence the owner sees.
///
/// One place, so the picker, the create screens and the submit-time
/// error handler cannot drift into saying three different things about
/// the same venue state.
String venueBlockMessage(AppLocalizations loc, VenueListingBlock block) {
  switch (block) {
    case VenueListingBlock.awaitingPayment:
      return loc.venueBlockAwaitingPayment;
    case VenueListingBlock.pending:
      return loc.venueBlockPending;
    case VenueListingBlock.needsRevision:
      return loc.venueBlockNeedsRevision;
    case VenueListingBlock.rejected:
      return loc.venueBlockRejected;
    case VenueListingBlock.subscriptionOverdue:
      return loc.venueBlockSubscriptionOverdue;
    case VenueListingBlock.unknown:
      return loc.venueBlockUnknown;
  }
}
