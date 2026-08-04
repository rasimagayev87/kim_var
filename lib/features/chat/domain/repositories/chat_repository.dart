import 'dart:io';

import '../entities/chat.dart';
import '../entities/chat_message.dart';

/// Abstraction over the chat backend (Firestore + Storage).
///
/// Chat ids are deterministic — the two participant uids, sorted and
/// joined with "_" — so there's exactly one chat document per pair and
/// no separate "find or create" round-trip is needed before sending.
abstract class ChatRepository {
  /// First page only, realtime — bounded by [limit] so this stays a
  /// cheap, live listener no matter how many chats the user has
  /// overall. Pair with [fetchMoreChats] for anything older.
  Stream<List<Chat>> watchChats(String myUid, {int limit = 30});

  /// One-shot fetch of the next page of chats older than [startAfter]
  /// (a chat's own [Chat.lastMessageAt]) — deliberately NOT realtime.
  /// Only the first page needs live reordering as new messages arrive;
  /// once a chat sees a new message it naturally reappears at the top
  /// of the live first page instead, so older pages can stay static
  /// snapshots without ever going stale in a way the user would notice.
  Future<List<Chat>> fetchMoreChats(String myUid, {required DateTime startAfter, int limit = 30});

  Future<void> setPinned(String chatId, String myUid, bool pinned);

  Future<void> setArchived(String chatId, String myUid, bool archived);

  Future<void> setMuted(String chatId, String myUid, bool muted);

  Stream<Chat?> watchChat(String chatId);

  Stream<List<ChatMessage>> watchMessages(String chatId);

  /// Creates the chat doc if needed and appends a text message.
  Future<void> sendTextMessage({
    required List<String> participantIds,
    required String senderId,
    required String text,
  });

  /// Creates the chat doc if needed, uploads [imageFile] to Storage,
  /// then appends an image message pointing at its download URL.
  /// [onProgress] (0.0-1.0), if given, is called as the upload advances.
  Future<void> sendImageMessage({
    required List<String> participantIds,
    required String senderId,
    required File imageFile,
    void Function(double progress)? onProgress,
  });

  /// Creates the chat doc if needed, uploads [videoFile] to Storage,
  /// then appends a video message pointing at its download URL.
  Future<void> sendVideoMessage({
    required List<String> participantIds,
    required String senderId,
    required File videoFile,
    int? durationMs,
    void Function(double progress)? onProgress,
  });

  /// Creates the chat doc if needed, uploads [audioFile] to Storage,
  /// then appends a voice message pointing at its download URL.
  Future<void> sendAudioMessage({
    required List<String> participantIds,
    required String senderId,
    required File audioFile,
    required int durationMs,
    void Function(double progress)? onProgress,
  });

  /// Creates the chat doc if needed and appends a message referencing an
  /// existing `posts/{postId}` doc — no upload, since the media already
  /// lives in Storage under the post's own path. [mediaUrl]/[isVideo] are
  /// a snapshot of the post at share time so the bubble can render
  /// without a live read.
  Future<void> sendPostMessage({
    required List<String> participantIds,
    required String senderId,
    required String postId,
    required String mediaUrl,
    required bool isVideo,
  });

  /// Hides [messageId] from [uid]'s own view only — the other
  /// participant's copy is untouched.
  Future<void> deleteMessageForMe({required String chatId, required String messageId, required String uid});

  /// Deletes [messageId] outright (and its Storage file, for media) —
  /// only the sender may call this, enforced both in
  /// [ChatController.deleteMessageForEveryone] (own-message check
  /// before the call) and the Firestore rule itself.
  Future<void> deleteMessageForEveryone({required String chatId, required String messageId});

  /// Re-sends an existing message's content into each of
  /// [targetOtherUids]' chats with the caller — no re-upload for media,
  /// same "point at the existing Storage URL" shape as
  /// [sendPostMessage].
  Future<void> forwardMessage({
    required List<String> targetOtherUids,
    required String senderId,
    required MessageType type,
    String? text,
    String? mediaUrl,
    int? durationMs,
    String? postId,
    bool postIsVideo,
  });

  Future<void> acceptChatRequest(String chatId);

  Future<void> declineChatRequest(String chatId);

  /// Called by the recipient's client when new messages arrive/are
  /// viewed, to advance delivered/read receipts and clear unread count.
  Future<void> markDelivered(String chatId, String myUid);

  Future<void> markRead(String chatId, String myUid);

  Future<void> setTyping({required String chatId, required String uid, required bool isTyping});

  Future<void> deleteChat(String chatId, String myUid);
}
