enum MessageType { text, image, video, audio, post, call }

enum CallMessageType { voice, video }

/// No `ongoing` value here on purpose — a call in progress is
/// represented by the live `calls/{callId}` doc (see `call_providers.dart`),
/// not by this message. The chat-log message for a given call is only
/// ever written once, after it reaches a terminal state.
enum CallMessageOutcome { missed, completed }

/// Where a confirmed [ChatMessage] sits in the delivery pipeline. There is
/// no `sending`/`failed` value here on purpose — those only apply to a
/// message that hasn't reached Firestore yet, which is represented by
/// [PendingOutgoingMessage] in the presentation layer instead. Once a
/// message exists in this stream at all, it has been written successfully.
enum MessageDeliveryStatus { sent, delivered, read }

class ChatMessage {
  final String id;
  final String senderId;

  /// The other participant at the time this message was sent. Derivable
  /// from the parent chat's `participants` too, but stored per-message
  /// so a message doc is self-describing on its own.
  final String receiverId;

  final String? text;

  /// Download URL for image/video/audio messages. Null for text.
  final String? mediaUrl;

  /// Audio/video clip length, in milliseconds. Null for text/image.
  final int? durationMs;

  /// The shared `posts/{id}` doc's id — set only for [MessageType.post].
  /// [mediaUrl]/[postIsVideo] are a denormalized snapshot of that post's
  /// media at share time, so the bubble can render without an extra
  /// live read; tapping it opens the full post via [postId].
  final String? postId;
  final bool postIsVideo;

  /// Set only for [MessageType.call] — who placed the call, distinct
  /// from [senderId] (which, for a call-log message, is whichever
  /// participant's device happened to write the log — see
  /// `firebase_chat_repository.dart`'s `logCallMessage`). The rail's
  /// arrow direction and "Cavab verilmədi" vs plain "Cavabsız" wording
  /// depend on comparing [callerId] against the viewing user's own uid,
  /// not against [senderId].
  final String? callerId;
  final CallMessageType? callMessageType;
  final CallMessageOutcome? callOutcome;

  /// Null for a missed call (never connected, so no duration/usage).
  final int? callDurationSeconds;
  final int? callDataUsageBytes;

  final MessageType type;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  /// Uids that chose "Özün üçün sil" on this message — it's filtered out
  /// of their own view only, the other participant's copy is untouched.
  /// "Hər kəs üçün sil" doesn't use this at all; it deletes the message
  /// doc outright (and its Storage file, for media) for both sides.
  final List<String> deletedFor;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.sentAt,
    this.text,
    this.mediaUrl,
    this.durationMs,
    this.postId,
    this.postIsVideo = false,
    this.callerId,
    this.callMessageType,
    this.callOutcome,
    this.callDurationSeconds,
    this.callDataUsageBytes,
    this.deliveredAt,
    this.readAt,
    this.deletedFor = const [],
  });

  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get isPost => type == MessageType.post;
  bool get isCall => type == MessageType.call;

  MessageDeliveryStatus get deliveryStatus {
    if (readAt != null) return MessageDeliveryStatus.read;
    if (deliveredAt != null) return MessageDeliveryStatus.delivered;
    return MessageDeliveryStatus.sent;
  }
}
