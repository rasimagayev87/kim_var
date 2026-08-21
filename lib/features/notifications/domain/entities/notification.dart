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

  /// A venue's live audience just spiked well above its usual level
  /// for this hour — see `computeVenueAudienceHistory` (scheduled
  /// Cloud Function). Owner-only; tapping opens Create Offer
  /// pre-filled with the venue (`targetType: 'venue_create_offer'`).
  venuePeakHour,

  /// A `birthdayMatches/{date}_{venueId}` doc was just created for this
  /// venue — see `computeBirthdayMatches` (scheduled Cloud Function).
  /// Owner-only. Deep-link navigation (opening Create Offer pre-filled
  /// with the matched users) lands with the birthday create-offer flow
  /// itself — until then this renders in the feed but does nothing on
  /// tap, same graceful "unrecognized targetType" fallback every other
  /// notification type gets from `notification_navigation.dart`.
  birthdayMatch,

  /// A `birthday` offer just got approved — sent to every uid in its
  /// `targetUserIds` (see `notifyBirthdayTargetUsers`, the approval
  /// branch of `onOfferUpdated`). `targetType: 'offer'`, same as any
  /// other approved-offer notification, so it opens
  /// `OfferDetailsScreen` with no extra navigation case needed — this
  /// type only exists to give it its own icon/copy in the feed.
  birthdayOffer,

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
  pinboxRejected,

  /// A venue published a new PinBox within this user's radius — see
  /// `notifyNearbyUsersOfNewPinBox` (Cloud Function). `targetType:
  /// 'pinbox'`, deep-links to `PinBoxCheckoutScreen`.
  pinboxNearby,

  /// Reserved for future use, not yet active — no producer anywhere
  /// today (no generic "system message" concept exists in the product,
  /// e.g. maintenance notices or policy updates).
  system,

  /// Reserved for future use, not yet active — no producer anywhere
  /// today (no security-alert feature exists, e.g. "new device login"
  /// or "password changed" notices).
  security,

  /// Admin-authored, sent via the admin panel's broadcast tool
  /// (`sendBroadcast` in `admin-panel/src/lib/actions/broadcast.ts`,
  /// `/notifications` page) — targets a segment (all/VIP/verified
  /// users), writes `title`/`body` verbatim (admin-typed, already in
  /// Azerbaijani) with no params contract, unlike every other type
  /// above. [promotion] and [announcement] are the same mechanism, two
  /// distinct types only so the admin can label intent (marketing push
  /// vs a general notice) and so the feed can give them separate
  /// icons/copy.
  promotion,

  /// Reserved for future use, not yet active — no producer anywhere
  /// today (no "official warning" moderation action exists in the
  /// admin panel; a ban/reject is the only account-level moderation
  /// outcome today).
  warning,

  /// Admin-authored broadcast — see [promotion]'s doc comment, the
  /// same `sendBroadcast` mechanism.
  announcement,
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
