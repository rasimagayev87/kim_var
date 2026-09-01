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

  /// P0 / H-4 — per-user "Söhbəti sil". Same uid-keyed-map shape as
  /// [archivedBy] right above, and for the same structural reason (one
  /// shared document, two participants), but it replaces something that
  /// used to be a real delete: `deleteChat` removed the shared document
  /// outright, and the `onChatDeleted` cascade then took BOTH people's
  /// messages and Storage media with it. Either participant could
  /// therefore erase the other's history — which, in the harassment
  /// case this app has to assume, is the abuser deleting the evidence
  /// out of the victim's own account.
  ///
  /// A client may only ever set its OWN key (`firestore.rules` enforces
  /// this on the map itself, not just the field name). The document is
  /// hard-deleted only once every participant's flag is `true`, by
  /// `hardDeleteFullyHiddenChat` (functions/src/index.ts), whose delete
  /// still runs the same `onChatDeleted` cleanup. A new message clears
  /// the map server-side, so the thread comes back for both sides.
  final Map<String, bool> hiddenFor;

  /// Post-launch QA — "məndən sil" (`deleteMessageForMe`) only ever hides
  /// a message for the ONE uid who deleted it; the shared [lastMessage]/
  /// [lastMessageType] on this same doc can't reflect that without also
  /// changing what the OTHER participant sees. Written exclusively by
  /// `onChatMessageDeletedForUser` (functions/src/index.ts, Admin SDK —
  /// `firestore.rules` blocks any client write to this field) whenever a
  /// uid's own "məndən sil" targets what was, at that moment, their own
  /// current preview. See [previewFor].
  /// Carries `at` — the `sentAt` of the message the override describes.
  ///
  /// Without it the override never expires. It was written once, when
  /// "məndən sil" hid what was then the newest message, and then won
  /// every comparison for ever: new messages updated `lastMessage` and
  /// `lastMessageAt`, but the chat list kept rendering the frozen text.
  /// Observed on device as a preview stuck on a message from the
  /// previous day while the row's timestamp showed the newest one.
  ///
  /// The server has always written `at` (`onChatMessageDeletedForUser`);
  /// the client simply dropped it while parsing.
  final Map<String, ({String text, MessageType? type, DateTime? at})> lastMessageOverride;

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
    this.hiddenFor = const {},
    this.lastMessageOverride = const {},
  });

  String otherParticipant(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => myUid);

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  bool isPinnedFor(String uid) => pinnedBy[uid] == true;

  bool isArchivedFor(String uid) => archivedBy[uid] == true;

  bool isMutedFor(String uid) => mutedBy[uid] == true;

  /// True when [uid] has removed this conversation from their own list.
  bool isHiddenFor(String uid) => hiddenFor[uid] == true;

  /// True when [uid] is the recipient of a still-pending request and
  /// must accept/decline before the conversation can continue.
  bool needsResponseFrom(String uid) =>
      status == ChatRequestStatus.pending && uid != initiatorId;

  /// The chat-list preview [uid] should actually see — their own
  /// [lastMessageOverride] entry if "məndən sil" has ever hidden what
  /// was their current preview, otherwise the shared [lastMessage]/
  /// [lastMessageType] every other participant without an override also
  /// sees. See [lastMessageOverride]'s own doc comment for who writes it
  /// and why it can never come from a raw client write.
  ({String text, MessageType? type}) previewFor(String uid) {
    final override = lastMessageOverride[uid];
    if (override != null && _overrideStillCurrent(override.at)) {
      return (text: override.text, type: override.type);
    }
    return (text: lastMessage, type: lastMessageType);
  }

  /// An override only describes the preview as of the message it was
  /// computed from. Anything newer supersedes it.
  ///
  /// EQUAL counts as current, deliberately: when the hidden message was
  /// itself the last one, the override's `at` is exactly
  /// [lastMessageAt], and that is precisely the case the override
  /// exists for. Treating equality as stale would show the deleted
  /// message straight back.
  ///
  /// A missing `at` (documents written before the field existed) is
  /// treated as current, so an old override still hides what it was
  /// meant to hide rather than resurfacing a deleted message.
  bool _overrideStillCurrent(DateTime? at) {
    if (at == null) return true;
    if (lastMessageAt == null) return true;
    return !at.isBefore(lastMessageAt!);
  }
}
