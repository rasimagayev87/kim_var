/// Why a venue cannot currently carry a new listing (campaign, PinBox
/// or event), or `null` when it can.
///
/// Exists because all three creation flows failed the same way: the
/// owner picked a venue that was not `approved`, filled in the whole
/// form, and got «Əməliyyat baş tutmadı» at the end. The server knew
/// exactly why — `submitOffer` throws `venue-not-approved`, and the
/// PinBox/event paths are refused by `venueIsLive()` in
/// `firestore.rules` — but every one of those reasons collapsed into
/// one generic sentence by the time it reached the screen.
///
/// Filling in a form and being refused at submit is the worst possible
/// ordering: the work is already done and the message explains nothing.
enum VenueListingBlock {
  /// Subscription payment never completed — the venue was created but
  /// the checkout was abandoned.
  awaitingPayment,

  /// Waiting on moderation.
  pending,

  /// Moderator asked for changes.
  needsRevision,

  /// Moderator rejected it.
  rejected,

  /// Subscription lapsed after having been paid.
  subscriptionOverdue,

  /// Any other non-approved state, including one added later that this
  /// enum has not caught up with. Deliberately present rather than
  /// falling through to "allowed": an unknown status must not be
  /// treated as usable, because the server will refuse it anyway and
  /// the owner would be back to the generic failure.
  unknown,
}

/// `null` means the venue may carry a listing.
///
/// Mirrors the server: `submitOffer` accepts only `approved`, and
/// `venueIsLive()` in `firestore.rules` gates PinBox and events on the
/// same value. This is a UX pre-check, never the enforcement — both of
/// those stay exactly as they are.
VenueListingBlock? venueListingBlock(String status) {
  switch (status) {
    case 'approved':
      return null;
    case 'awaiting_payment':
      return VenueListingBlock.awaitingPayment;
    case 'pending':
      return VenueListingBlock.pending;
    case 'needs_revision':
      return VenueListingBlock.needsRevision;
    case 'rejected':
      return VenueListingBlock.rejected;
    case 'subscription_overdue':
      return VenueListingBlock.subscriptionOverdue;
    default:
      return VenueListingBlock.unknown;
  }
}
