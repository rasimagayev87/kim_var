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
  follow,
  followRequest,
  followAccepted,
  likePost,
  commentPost,
  replyComment,
  mention,
  venueOffer,
  venueAdded,
  venueVerified,
  system,
  security,
  promotion,
  warning,
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
