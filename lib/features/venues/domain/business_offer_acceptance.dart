/// Whether a venue must re-accept the "PeakPin Biznes Xidmətlərinin
/// Publik Ofertası" before its next subscription payment can proceed —
/// true when it never accepted any version at all ([acceptedVersion]
/// null, e.g. a venue created before this feature existed) or when the
/// version it last accepted no longer matches [currentVersion]
/// (`AppConfig.businessOfferVersion`). Pulled out of
/// `_SubscriptionOverdueBannerState._pay()` (`my_venues_screen.dart`)
/// so this one comparison can be unit-tested without standing up the
/// whole widget.
bool needsBusinessOfferReacceptance({
  required String? acceptedVersion,
  required String currentVersion,
}) {
  return acceptedVersion == null || acceptedVersion != currentVersion;
}
