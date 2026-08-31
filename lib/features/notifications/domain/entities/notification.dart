/// Every social/system event this app raises a notification for.
/// Message-related events (new_message, message_request, typing,
/// read_receipt, voice_call, video_call, message_reaction) are
/// deliberately excluded — those live entirely in the "Söhbət" module
/// and never produce a doc in `users/{uid}/notifications`.
///
/// [other] is the forward-compatible fallback: a server-written type
/// this build doesn't recognize yet still renders (generic icon/copy)
/// instead of crashing, so adding a new type server-side never requires
/// a synchronized app release.
enum NotificationType {
  /// The server's actual type string for an instant follow of a
  /// `public` account (see `onFollowCreated` in functions/src/index.ts).
  newFollower,

  /// A follow REQUEST against a `private` account — see "Hesab
  /// gizliliyi", `onFollowCreated`'s `pending`-status branch.
  followRequest,

  /// The followee approved a pending [followRequest] — see
  /// `onFollowUpdated`.
  followAccepted,
  likePost,
  commentPost,
  replyComment,

  /// Reserved for future use, not yet active — no @-mention parsing
  /// exists anywhere in posts/comments today (nothing extracts an
  /// `@username` out of comment text), so nothing ever produces this.
  /// Icon/copy scaffolding already exists (`notifications_feed_screen
  /// .dart`) per this enum's own forward-compat design; a real mention
  /// feature would just need its own Cloud Function producer, nothing
  /// client-side.
  mention,
  venueOffer,
  venueAdded,
  venueVerified,

  /// A venue's subscription cycle is due and needs a fresh Epoint
  /// payment — see `renewVenueSubscriptions` (scheduled Cloud
  /// Function). Owner-only. `targetType: 'venue_subscription_due'`,
  /// opens `MyVenuesScreen` where the overdue venue shows its own
  /// "Ödə" banner (`retryVenueSubscriptionPayment`).
  venueSubscriptionDue,

  /// Admin moderation decisions on a venue/offer — see
  /// `moderationStatusNotification` in functions/src/index.ts, which is
  /// the single producer for all 6 of these.
  venueApproved,
  venueNeedsRevision,
  venueRejected,
  offerApproved,
  offerNeedsRevision,
  offerRejected,

  /// A real Epoint charge cleared — see `applyPaymentOutcome`'s
  /// post-transaction notify block (functions/src/index.ts), the only
  /// producer for all 4 of these. Exists because the card checkout
  /// flow opens in the device's EXTERNAL browser
  /// (`launchUrl(..., mode: .externalApplication)`), so the app itself
  /// has no way to detect the user coming back — without a push, the
  /// only way an owner would ever find out their payment went through
  /// is by happening to reopen the exact right screen later.
  /// [offerPaymentConfirmed]: the offer's placement fee cleared — it's
  /// now `pending`, awaiting admin review (not live yet).
  /// [offerBoosted]: a "Təklifi önə çək" charge cleared —
  /// `Offer.boostedUntil` is set, live immediately.
  /// [venuePaymentConfirmed]: a brand new venue's FIRST subscription
  /// charge cleared (`submitVenue`) — it's now `pending`, awaiting
  /// admin review, same "not live yet" meaning as [offerPaymentConfirmed].
  /// Distinct from [venueSubscriptionRenewed] so the copy never says
  /// "renewed" for a venue that was never live before.
  /// [venueSubscriptionRenewed]: an EXISTING venue's recurring
  /// subscription charge cleared.
  /// [pinboxOrderConfirmed]: buyer-side — a PinBox order charge
  /// cleared, the QR ticket is ready.
  /// [venuePremiumActivated]: a "Məkanı premium et" charge cleared —
  /// `Venue.isPremium`/`premiumExpiresAt` are set, live immediately
  /// (not an admin-review gate, unlike the subscription ones above).
  offerPaymentConfirmed,
  offerBoosted,
  venuePaymentConfirmed,
  venueSubscriptionRenewed,
  venuePremiumActivated,
  pinboxOrderConfirmed,

  /// A venue's premium period ends in 3-5 days — see
  /// `expireVenuePremium` (scheduled Cloud Function). No auto-renewal
  /// exists (Epoint's `card_uid` token needs a fresh user-present
  /// checkout every time), so this is purely informational, pointing
  /// the owner at `VenuePremiumInfoScreen`'s "erkən yenilə" button.
  venuePremiumExpiringSoon,

  /// A customer joined this venue's "Növbə" (walk-in waitlist) — see
  /// `joinWaitlist`, functions/src/index.ts. Owner-only. Previously the
  /// owner had no signal at all beyond manually reopening
  /// `VenueWaitlistScreen` and noticing a new row; `targetType:
  /// 'venue_waitlist'` (not plain `'venue'`) routes a tap straight to
  /// that screen so they can act on it (call/seat) immediately — see
  /// `notification_navigation.dart`.
  venueWaitlistJoined,

  /// The bank declined the charge — same producer/reasoning as the 4
  /// above, `params: {name, reason}` where `reason` is Epoint's own
  /// bank-decline code translated to AZ (`bankDeclineMessage` in
  /// functions/src/index.ts, e.g. "Kartınızda kifayət qədər vəsait
  /// yoxdur" for insufficient funds) — never a bare "failed", so the
  /// owner/buyer actually knows why and can act on it.
  paymentFailed,

  /// A venue's live audience just spiked well above its usual level
  /// for this hour — see `computeVenueAudienceHistory` (scheduled
  /// Cloud Function). Owner-only; tapping opens Create Offer
  /// pre-filled with the venue (`targetType: 'venue_create_offer'`).
  venuePeakHour,

  /// The 11:00 nudge: people nearby have a birthday today, and the
  /// owner has until 13:00 to publish a campaign for them — see
  /// `computeBirthdayMatches` (scheduled Cloud Function). Owner-only,
  /// and one per owner rather than one per venue.
  ///
  /// With a single matched venue `targetType: 'birthday_match'` opens
  /// Create Offer pre-filled with that match; with several there is no
  /// one match to pre-fill from, so it is `'my_venues'` and the owner
  /// picks. Both are handled in `notification_navigation.dart`.
  birthdayMatch,

  /// RETIRED as of the birthday-flow rebuild. A `birthday` offer used
  /// to push at the moment it was approved; approval now publishes
  /// nothing and `publishBirthdayCampaigns` sends [birthdayVenues]
  /// instead, once, at 13:00.
  ///
  /// Kept in this enum — and in `notification_localizer.dart` — because
  /// notifications already written with this type are still sitting in
  /// users' feeds, and removing the case would render them blank.
  birthdayOffer,

  /// The day's birthday campaigns, published together at 13:00 — see
  /// `publishBirthdayCampaigns` (Cloud Function). Names up to three
  /// venues, each from a different category.
  ///
  /// `targetType: 'birthday_feed'`, `targetId` = the Baku date key, so
  /// tapping opens the "Ad günü fürsətləri" list rather than any one
  /// venue: the whole point of the 13:00 moment is that several
  /// campaigns arrive at once.
  birthdayVenues,

  /// The daily opportunity digest — one per content kind, at most three
  /// a day, sent by `sendDailyOpportunityDigest` at 15:00 in place of
  /// the per-listing fan-out that used to send one push per venue.
  ///
  /// `targetType: 'live_feed'` with no `targetId`: a digest summarises
  /// many listings, so there is no single document to open and the
  /// destination is the Canlı tab.
  dailyOffersDigest,
  dailyPinboxDigest,
  dailyEventsDigest,

  /// Owner just called this user forward in a venue's waitlist — see
  /// `callWaitlistEntry` (Cloud Function). `targetType: 'venue'`, same
  /// as any other venue notification, since the user's own live queue
  /// position already renders on `VenueProfileScreen` itself.
  waitlistCalled,

  /// The venue's waitlist got force-disabled while this user still had
  /// a `waiting` entry — see `disableWaitlistOnIneligibleCategory`
  /// (Cloud Function), which fires when an owner changes their venue's
  /// category to one no longer allowed to run a waitlist. `targetType:
  /// 'venue'`, same as `waitlistCalled`.
  waitlistDisabled,

  /// A venue published a new event within this user's radius — see
  /// `notifyNearbyUsersOfNewEvent` (Cloud Function). `targetType:
  /// 'event'`, deep-links to `EventDetailsScreen(eventId: ...)`.
  venueEvent,

  /// `users/{uid}.premium` just flipped false -> true — see
  /// `onUserUpdated` (Cloud Function). No `targetId`/`targetType`;
  /// nothing to deep-link to.
  vipGranted,

  /// Admin approved/rejected an `identityVerifications/{requestId}` —
  /// see `onIdentityVerificationUpdated` (Cloud Function). No
  /// `targetId`/`targetType` for the approved case; the rejected case
  /// carries the admin's reason in `params.note`, same shape as
  /// [venueRejected].
  identityVerificationApproved,
  identityVerificationRejected,

  /// "Fərdi Prodakşn/Sənətçi" (`independentArtist`) venue published a
  /// new offer or event — sent to every follower
  /// (`venues/{venueId}/followers`), no radius ceiling, unlike
  /// [venueOffer]/[venueEvent]. `targetType`/`targetId` are `offer`/
  /// `event` same as those two, whichever kind of post triggered it —
  /// this only exists to give the follow-based case its own icon/copy
  /// in the feed.
  productionPost,

  /// PinBox equivalent of [venueAdded] — see `onPinBoxCreated` (Cloud
  /// Function). `targetType: 'pinbox'`.
  pinboxAdded,

  /// Admin moderation decision on a PinBox — see
  /// `moderationStatusNotification`'s `"pinbox"` branch,
  /// `onPinBoxUpdated` (Cloud Function). PinBox has no `needs_revision`
  /// state (see `PinBoxRepository`'s own doc comment), so unlike the
  /// venue/offer pair above there's no third [pinboxNeedsRevision] type
  /// — only these two.
  pinboxApproved,

  /// Was genuinely missing until now — `moderationStatusNotification`
  /// (functions/src/index.ts) already handled `needs_revision` for
  /// EVERY kind generically, this app's own enum just never had a case
  /// for the PinBox one, so a real admin "send back for revision"
  /// decision silently fell through to [other]'s generic icon/copy.
  pinboxNeedsRevision,
  pinboxRejected,

  /// A venue published a new PinBox within this user's radius — see
  /// `notifyNearbyUsersOfNewPinBox` (Cloud Function). `targetType:
  /// 'pinbox'`, deep-links to `PinBoxCheckoutScreen`.
  pinboxNearby,

  /// Admin-authored, sent via the admin panel's broadcast tool
  /// (`sendBroadcast` in `admin-panel/src/lib/actions/broadcast.ts`,
  /// `/notifications` page) — targets a segment (all/VIP/verified
  /// users), writes `title`/`body` verbatim (admin-typed, already in
  /// Azerbaijani) with no params contract, unlike every other type
  /// above. [promotion]/[announcement]/[system] are the same
  /// mechanism, three distinct types only so the admin can label
  /// intent (marketing push vs. a general notice vs. an official
  /// system message) and so the feed can give them separate
  /// icons/copy. Gated behind `NotificationPreferences.marketing` for
  /// [promotion], `.systemNotifications` for the other two.
  system,

  /// Two producers, both in functions/src/index.ts: (1)
  /// `notifyOnNewDeviceSignIn` (Identity Platform Blocking Function) —
  /// a sign-in whose `userAgent` doesn't match any of the account's
  /// recent `knownDeviceSignatures`, `params: {kind: 'new_device'}`;
  /// (2) `onUserUpdated` (Cloud Function) — the account's contact
  /// `email` field actually changing (not being set for the first
  /// time), `params: {kind: 'email_changed', newEmail}`.
  security,

  /// Admin-authored broadcast — see [system]'s doc comment, the same
  /// `sendBroadcast` mechanism.
  promotion,

  /// Admin-authored, sent via the admin panel's `sendUserWarning`
  /// (`admin-panel/src/lib/actions/users.ts`, the user detail page's
  /// "Xəbərdarlıq göndər" button) — a moderation action a step short
  /// of a ban, `params: {reason}`. Unlike [promotion]/[announcement]/
  /// [system], NOT gated behind any notification preference — same
  /// stance as every other moderation-outcome type
  /// ([venueRejected]/[pinboxRejected]/etc.).
  warning,

  /// Admin-authored broadcast — see [system]'s doc comment, the same
  /// `sendBroadcast` mechanism.
  announcement,

  /// 2 hours after a waitlist entry is marked `seated` ("Gəldi") — see
  /// `sendReviewPrompts` (scheduled Cloud Function). `targetType:
  /// 'venue'`, so it opens `VenueProfileScreen` the same way any other
  /// venue-targeted notification already does; the guest taps "Rəy
  /// yaz" themselves once there. `params: {venueId, venueName,
  /// waitlistEntryId}`.
  reviewPrompt,
  other,
}

NotificationType notificationTypeFromString(String raw) {
  return NotificationType.values.firstWhere(
    (t) => t.name == raw,
    orElse: () => NotificationType.other,
  );
}

/// A single entry in `users/{uid}/notifications`. Read-model only —
/// this app never creates these client-side (see
/// [NotificationRepository] doc comment), so there's no companion
/// "create" use case the way [Post]/[Story] have one.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? imageUrl;
  final String? senderId;
  final String? senderName;
  final String? senderPhoto;
  final String? targetId;

  /// What [targetId] points at — e.g. `profile`, `post`, `comment`,
  /// `venue`, `venue_offer`. Kept as a plain string rather than an enum:
  /// this is server-authored data, and deep-link routing already needs
  /// a default/unknown branch for forward compatibility, so an enum
  /// here would only add a translation step without adding safety.
  final String? targetType;

  final bool isRead;
  final DateTime createdAt;

  /// Precomputed navigation target (e.g. `/venue/abc123`). When absent,
  /// routing falls back to [targetType]/[targetId].
  final String? deepLink;

  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.senderId,
    this.senderName,
    this.senderPhoto,
    this.targetId,
    this.targetType,
    this.isRead = false,
    required this.createdAt,
    this.deepLink,
    this.metadata,
  });
}
