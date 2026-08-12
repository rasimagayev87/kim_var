/// Who can see this user's profile MEDIA (the post grid) — nothing
/// else. Deliberately unrelated to Discover/map visibility, which is
/// [PrivacySettings.ghostModeEnabled]'s job alone; a `noOne` profile
/// here still shows up in Discover with its stats intact, just with
/// the grid replaced by a "Bağlı profil" notice for anyone who isn't
/// allowed to see it.
///
/// `followersOnly` is enforced against the real `follows` graph (see
/// `follow_providers.dart`) — either direction counts (the viewer
/// follows the owner, or the owner follows the viewer), not just
/// "owner's followers" in the strict one-way sense.
enum ProfileVisibility { everyone, followersOnly, noOne }

/// `followersOnly` is enforced the same way as [ProfileVisibility]'s own
/// `followersOnly` — against the real `follows` graph
/// (`FirebaseChatRepository._canMessage`), either direction counting,
/// checked server-side before a brand-new chat is allowed to start
/// (see `_sendMessage`'s `!chatExistsAlready` branch — an already-
/// accepted conversation is never retroactively blocked).
enum WhoCanMessageMe { everyone, followersOnly }

/// Which of the 3 "Görünmə radiusu" modes is active — mirrors
/// `DiscoverRadiusMode` in `location_providers.dart` (distance ring,
/// Ölkə üzrə, or Dünya üzrə), kept as its own enum here rather than an
/// import since this is a domain entity and that one lives in a
/// presentation-layer provider file.
enum VisibilityRadiusMode { distance, country, world }

/// One document's worth of a user's privacy/security preferences —
/// mirrors fields living on their own `users/{uid}` Firestore doc
/// (merged in alongside the existing `blockedUsers`, `premium`, etc.
/// fields already written there), not a separate collection.
class PrivacySettings {
  final ProfileVisibility profileVisibility;

  /// Which radius mode other users can see this user from — reuses the
  /// same breakpoints/gating as Discover's own search radius
  /// (`kRadiusOptionsKm`/`isPremiumRadiusKm` in `location_providers.dart`):
  /// 0.1/0.5/1 km free, 5/10/30 km + Ölkə üzrə + Dünya üzrə Premium.
  final VisibilityRadiusMode visibilityRadiusMode;

  /// Only meaningful when [visibilityRadiusMode] is `distance` — null
  /// (and ignored) for `country`/`world`.
  final double? visibilityRadiusKm;

  final bool showOnlineStatus;

  /// Mirrors WhatsApp/Telegram's read-receipt trade-off: turning this
  /// off also hides other people's read receipts from this user (the UI
  /// spells that out — see `eventGenericErrorMessage`-style copy planned
  /// for this screen).
  final bool showReadReceipts;

  final WhoCanMessageMe whoCanMessageMe;

  final bool twoFactorEnabled;

  /// Premium-gated (UI-level check, same pattern as the locked 5/10km
  /// Discover radius options — see `isPremiumRadiusKm`). Its ONLY job
  /// is hiding this user from Discover/the nearby map; independent of
  /// [profileVisibility], which governs media instead. A ghost-mode
  /// user's profile page is still fully reachable (and its media still
  /// governed by [profileVisibility]) to anyone who already has a way
  /// to it — a chat, a direct link, an existing follow.
  final bool ghostModeEnabled;

  /// Opt-IN (default false, never opt-out) — whether nearby venues'
  /// birthday-match Cloud Function may consider this user at all on
  /// their birthday. Off means invisible to that matching entirely,
  /// not just "no offers shown" — see `computeBirthdayMatches`'s own
  /// doc comment in `functions/src/index.ts`.
  final bool birthdayOffersOptIn;

  const PrivacySettings({
    this.profileVisibility = ProfileVisibility.everyone,
    this.visibilityRadiusMode = VisibilityRadiusMode.distance,
    this.visibilityRadiusKm = 1.0,
    this.showOnlineStatus = true,
    this.showReadReceipts = true,
    this.whoCanMessageMe = WhoCanMessageMe.everyone,
    this.twoFactorEnabled = false,
    this.ghostModeEnabled = false,
    this.birthdayOffersOptIn = false,
  });

  PrivacySettings copyWith({
    ProfileVisibility? profileVisibility,
    VisibilityRadiusMode? visibilityRadiusMode,
    double? visibilityRadiusKm,
    bool clearRadiusKm = false,
    bool? showOnlineStatus,
    bool? showReadReceipts,
    WhoCanMessageMe? whoCanMessageMe,
    bool? twoFactorEnabled,
    bool? ghostModeEnabled,
    bool? birthdayOffersOptIn,
  }) {
    return PrivacySettings(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      visibilityRadiusMode: visibilityRadiusMode ?? this.visibilityRadiusMode,
      visibilityRadiusKm: clearRadiusKm ? null : (visibilityRadiusKm ?? this.visibilityRadiusKm),
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      whoCanMessageMe: whoCanMessageMe ?? this.whoCanMessageMe,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      ghostModeEnabled: ghostModeEnabled ?? this.ghostModeEnabled,
      birthdayOffersOptIn: birthdayOffersOptIn ?? this.birthdayOffersOptIn,
    );
  }
}
