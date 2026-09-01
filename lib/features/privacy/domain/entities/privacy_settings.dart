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
///
/// Superseded by [AccountPrivacy] — the "Media görünürlüyü" settings
/// row that wrote this field is gone as of that feature's FAZA 2, and
/// its FAZA 3 rewires `UserProfileScreen`'s media gate to
/// [AccountPrivacy] instead. This field/enum stays only so existing
/// Firestore data isn't orphaned; nothing new reads or writes it.
enum ProfileVisibility { everyone, followersOnly, noOne }

/// `followersOnly` is enforced the same way as [ProfileVisibility]'s own
/// `followersOnly` — against the real `follows` graph
/// (`FirebaseChatRepository._canMessage`), either direction counting,
/// checked server-side before a brand-new chat is allowed to start
/// (see `_sendMessage`'s `!chatExistsAlready` branch — an already-
/// accepted conversation is never retroactively blocked).
enum WhoCanMessageMe { everyone, followersOnly }

/// Account-level privacy — replaces [ProfileVisibility] as the single
/// gate for "can another user see this account's media, follow/
/// follower lists, and avatar tap actions" (see `UserProfileScreen`'s
/// FAZA 3 gating). `private` also switches the follow flow from an
/// instant follow to a request/approve one (see the follow feature's
/// own FAZA 4 doc comments) and becomes the default visibility for new
/// stories (FAZA 5) — this single field now covers what
/// [ProfileVisibility]'s `followersOnly`/`noOne` and each story's own
/// `visibility` field used to handle separately.
enum AccountPrivacy { public, private }

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

  /// See [AccountPrivacy]'s own doc comment. Defaults `public` for
  /// every existing account (migration decision — nobody switches to
  /// `private` behavior without explicitly opting in from the new
  /// "Hesab gizliliyi" row).
  final AccountPrivacy accountPrivacy;

  /// Which radius mode other users can see this user from — reuses the
  /// same options as Discover's own search radius (`kRadiusOptionsKm`
  /// in `location_providers.dart`): all km values are free, only
  /// Ölkə üzrə/Dünya üzrə require Premium.
  final VisibilityRadiusMode visibilityRadiusMode;

  /// Only meaningful when [visibilityRadiusMode] is `distance` — null
  /// (and ignored) for `country`/`world`.
  final double? visibilityRadiusKm;

  /// Mirrors WhatsApp/Telegram's read-receipt trade-off: turning this
  /// off also hides other people's read receipts from this user (the UI
  /// spells that out — see `eventGenericErrorMessage`-style copy planned
  /// for this screen).
  final bool showReadReceipts;

  final WhoCanMessageMe whoCanMessageMe;

  final bool twoFactorEnabled;

  /// Premium-gated (UI-level check, same pattern as the locked Ölkə/
  /// Dünya Discover radius options). Its ONLY job
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

  /// Premium-gated, same UI-level check as [ghostModeEnabled] — but a
  /// DIFFERENT axis entirely: this hides the fact that *this user*
  /// viewed *someone else's* profile (no `profileViews` doc gets
  /// written, see `recordProfileVisitProvider`), while [ghostModeEnabled]
  /// hides this user from Discover/the nearby map. A user can have
  /// either, both, or neither independently.
  final bool incognitoBrowsingEnabled;

  const PrivacySettings({
    this.profileVisibility = ProfileVisibility.everyone,
    this.accountPrivacy = AccountPrivacy.public,
    this.visibilityRadiusMode = VisibilityRadiusMode.distance,
    this.visibilityRadiusKm = 1.0,
    this.showReadReceipts = true,
    this.whoCanMessageMe = WhoCanMessageMe.everyone,
    this.twoFactorEnabled = false,
    this.ghostModeEnabled = false,
    this.birthdayOffersOptIn = false,
    this.incognitoBrowsingEnabled = false,
  });

  PrivacySettings copyWith({
    ProfileVisibility? profileVisibility,
    AccountPrivacy? accountPrivacy,
    VisibilityRadiusMode? visibilityRadiusMode,
    double? visibilityRadiusKm,
    bool clearRadiusKm = false,
    bool? showReadReceipts,
    WhoCanMessageMe? whoCanMessageMe,
    bool? twoFactorEnabled,
    bool? ghostModeEnabled,
    bool? birthdayOffersOptIn,
    bool? incognitoBrowsingEnabled,
  }) {
    return PrivacySettings(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      accountPrivacy: accountPrivacy ?? this.accountPrivacy,
      visibilityRadiusMode: visibilityRadiusMode ?? this.visibilityRadiusMode,
      visibilityRadiusKm: clearRadiusKm
          ? null
          : (visibilityRadiusKm ?? this.visibilityRadiusKm),
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      whoCanMessageMe: whoCanMessageMe ?? this.whoCanMessageMe,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      ghostModeEnabled: ghostModeEnabled ?? this.ghostModeEnabled,
      birthdayOffersOptIn: birthdayOffersOptIn ?? this.birthdayOffersOptIn,
      incognitoBrowsingEnabled:
          incognitoBrowsingEnabled ?? this.incognitoBrowsingEnabled,
    );
  }
}
