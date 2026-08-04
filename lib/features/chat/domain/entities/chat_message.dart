enum MessageType { text, image, video, audio, post }

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
    this.deliveredAt,
    this.readAt,
    this.deletedFor = const [],
  });

  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get isPost => type == MessageType.post;

  MessageDeliveryStatus get deliveryStatus {
    if (readAt != null) return MessageDeliveryStatus.read;
    if (deliveredAt != null) return MessageDeliveryStatus.delivered;
    return MessageDeliveryStatus.sent;
  }
}
