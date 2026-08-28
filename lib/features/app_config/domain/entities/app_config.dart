/// The result of comparing the installed app version against what
/// Remote Config says is currently required/available.
enum UpdateStatus { upToDate, softUpdateAvailable, forceUpdateRequired }

/// One flag per remotely-toggleable feature — see each gate point's own
/// call site (`ref.watch(featureFlagProvider(FeatureFlag.x))`) for where
/// it's actually wired. `indiTab` and `newsAgency` exist here so Remote
/// Config already carries their keys, even though neither has a real UI
/// gate yet (see this feature's own plan/audit notes): `indiTab` has no
/// standalone tab in this app today (closest match is the "İndi boş yer
/// var" section inside the Canlı tab), and `newsAgency` has no dedicated
/// flow (only the `VenueCategory.independentArtist` venue category).
enum FeatureFlag {
  venueSubmission,
  offers,
  indiTab,
  calls,
  stories,
  vipPurchase,
  boostPayment,
  waitlist,
  newsAgency,
  mediaUpload,
}

/// Every value this app can change remotely without a new build —
/// [AppConfigRepository] fills this from Firebase Remote Config, always
/// falling back to the bundled default (matching the current hardcoded
/// value it replaces, where one existed) if a key is missing or malformed.
class AppConfig {
  const AppConfig({
    this.forceUpdateEnabled = false,
    this.minSupportedVersionAndroid = '1.0.0',
    this.minSupportedVersionIos = '1.0.0',
    this.latestVersionAndroid = '1.0.0',
    this.latestVersionIos = '1.0.0',
    this.updateStoreUrlAndroid = 'https://play.google.com/store/apps/details?id=com.peakpin.app',
    this.updateStoreUrlIos = 'https://apps.apple.com/app/id0000000000',
    this.softUpdateIntervalHours = 72,
    this.maintenanceModeEnabled = false,
    this.maintenanceMessage = '',
    this.readOnlyModeEnabled = false,
    this.readOnlyMessage = '',
    this.announcementEnabled = false,
    this.announcementId = '',
    this.announcementMessage = '',
    this.announcementActionUrl = '',
    this.featureFlags = const {
      FeatureFlag.venueSubmission: true,
      FeatureFlag.offers: true,
      FeatureFlag.indiTab: true,
      FeatureFlag.calls: true,
      FeatureFlag.stories: true,
      FeatureFlag.vipPurchase: true,
      FeatureFlag.boostPayment: true,
      FeatureFlag.waitlist: true,
      FeatureFlag.newsAgency: true,
      FeatureFlag.mediaUpload: true,
    },
    this.urlPrivacyPolicy = 'https://peakpin.app/privacy-policy.html',
    this.urlTermsOfService = 'https://peakpin.app/terms-of-service.html',
    this.urlCommunityGuidelines = 'https://peakpin.app/community-guidelines.html',
    this.urlBusinessOffer = 'https://peakpin.app/business-offer.html',
    this.businessOfferVersion = '1.0',
    this.businessOfferEffectiveDate = '2026-08-28',
    this.urlChildSafetyStandards = 'https://peakpin.app/child-safety-standards.html',
    this.supportEmail = 'support@peakpin.app',
    this.privacyEmail = 'privacy@peakpin.app',
    this.supportPhone = '',
    this.radiusOptionsKm = const [0.1, 0.5, 1, 5, 10, 30],
    this.vipRadiusThresholdM = 0,
    this.socialInstagramUrl = '',
    this.socialTiktokUrl = '',
  });

  final bool forceUpdateEnabled;
  final String minSupportedVersionAndroid;
  final String minSupportedVersionIos;
  final String latestVersionAndroid;
  final String latestVersionIos;
  final String updateStoreUrlAndroid;
  final String updateStoreUrlIos;
  final int softUpdateIntervalHours;

  final bool maintenanceModeEnabled;
  /// Already resolved to the app's current locale by the repository.
  final String maintenanceMessage;

  final bool readOnlyModeEnabled;
  /// Already resolved to the app's current locale by the repository.
  final String readOnlyMessage;

  final bool announcementEnabled;
  final String announcementId;
  /// Already resolved to the app's current locale by the repository.
  final String announcementMessage;
  final String announcementActionUrl;

  final Map<FeatureFlag, bool> featureFlags;

  final String urlPrivacyPolicy;
  final String urlTermsOfService;
  final String urlCommunityGuidelines;
  final String urlBusinessOffer;
  /// Compared against a venue's own `offerAcceptedVersion` (see
  /// `Venue`) to decide whether a fresh acceptance is required before
  /// the next subscription payment — see
  /// `business_offer_consent_row.dart` and `MyVenuesScreen`'s
  /// re-acceptance sheet.
  final String businessOfferVersion;
  /// ISO date string, shown in the non-blocking "oferta yeniləndi"
  /// banner — purely informational, not parsed/compared against
  /// anything.
  final String businessOfferEffectiveDate;
  final String urlChildSafetyStandards;
  final String supportEmail;
  final String privacyEmail;
  final String supportPhone;
  final List<double> radiusOptionsKm;
  /// Not wired to any behavior yet — today country/world discover modes
  /// are simply VIP-gated outright (see `isPremiumProvider` call sites in
  /// `discover_tab.dart`/`privacy_security_screen.dart`), not gated by a
  /// numeric distance threshold. Reserved for that future shape.
  final double vipRadiusThresholdM;
  final String socialInstagramUrl;
  final String socialTiktokUrl;

  bool isFeatureEnabled(FeatureFlag flag) => featureFlags[flag] ?? true;
}
