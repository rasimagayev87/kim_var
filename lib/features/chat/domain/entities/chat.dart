import 'chat_message.dart';

/// A chat starts `pending` (only [initiatorId] may send, and only one
/// message) until the other participant calls `acceptChatRequest`, which
/// flips it to `accepted` and unlocks free back-and-forth. `declined`
/// means the recipient explicitly rejected the request.
enum ChatRequestStatus { pending, accepted, declined }

class Chat {
  final String id;
  final List<String> participantIds;
  final String initiatorId;

  /// [initiatorId]'s Premium status AT THE MOMENT the chat was created —
  /// captured once (not re-synced if their status changes later) purely
  /// to drive "VIP göndərənlər önə çıxsın" ordering in the Sorğular tab
  /// (see `ChatsTab._visibleChats`), not a live premium check.
  final bool initiatorIsPremium;
  final ChatRequestStatus status;
  final String lastMessage;
  final MessageType? lastMessageType;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final String? typingUserId;

  /// Per-user "sabitlə" state — a shared doc, not one-per-user, so this
  /// (and [archivedBy]/[mutedBy] below) is a map keyed by uid rather
  /// than a single flag, matching how [unreadCount] already tracks
  /// per-participant state on the same doc.
  final Map<String, bool> pinnedBy;
  final Map<String, bool> archivedBy;
  final Map<String, bool> mutedBy;

  const Chat({
    required this.id,
    required this.participantIds,
    required this.initiatorId,
    this.initiatorIsPremium = false,
    required this.status,
    this.lastMessage = '',
    this.lastMessageType,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    this.typingUserId,
    this.pinnedBy = const {},
    this.archivedBy = const {},
    this.mutedBy = const {},
  });

  String otherParticipant(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => myUid);

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  bool isPinnedFor(String uid) => pinnedBy[uid] == true;

  bool isArchivedFor(String uid) => archivedBy[uid] == true;

  bool isMutedFor(String uid) => mutedBy[uid] == true;

  /// True when [uid] is the recipient of a still-pending request and
  /// must accept/decline before the conversation can continue.
  bool needsResponseFrom(String uid) => status == ChatRequestStatus.pending && uid != initiatorId;
}
