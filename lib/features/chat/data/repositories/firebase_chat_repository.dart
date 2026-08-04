import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/chat_failure.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Deterministic id — sorted participant uids joined with "_" — so
  /// there's exactly one chat doc per pair and sending never needs a
  /// separate "find or create" round-trip.
  static String chatIdFor(List<String> participantIds) {
    final sorted = [...participantIds]..sort();
    return sorted.join('_');
  }

  CollectionReference<Map<String, dynamic>> get _chats => _firestore.collection('chats');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Stream<List<Chat>> watchChats(String myUid, {int limit = 30}) {
    return _chats
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _chatFromDoc(d.id, d.data())).toList());
  }

  @override
  Future<List<Chat>> fetchMoreChats(String myUid, {required DateTime startAfter, int limit = 30}) async {
    final snap = await _chats
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .startAfter([Timestamp.fromDate(startAfter)])
        .limit(limit)
        .get();
    return snap.docs.map((d) => _chatFromDoc(d.id, d.data())).toList();
  }

  @override
  Future<void> setPinned(String chatId, String myUid, bool pinned) {
    return _chats.doc(chatId).update({'pinnedBy.$myUid': pinned});
  }

  @override
  Future<void> setArchived(String chatId, String myUid, bool archived) {
    return _chats.doc(chatId).update({'archivedBy.$myUid': archived});
  }

  @override
  Future<void> setMuted(String chatId, String myUid, bool muted) {
    return _chats.doc(chatId).update({'mutedBy.$myUid': muted});
  }

  @override
  Stream<Chat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((d) => d.exists ? _chatFromDoc(d.id, d.data()!) : null);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    // Bounded to the most recent 200 — fine for an MVP; paginate
    // further back once conversations regularly exceed that.
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.reversed.map((d) => _messageFromDoc(d.id, d.data(), chatId)).toList());
  }

  @override
  Future<void> sendTextMessage({
    required List<String> participantIds,
    required String senderId,
    required String text,
  }) {
    return _sendMessage(
      participantIds: participantIds,
      senderId: senderId,
      buildMessage: (receiverId) => {
        'senderId': senderId,
        'receiverId': receiverId,
        'type': 'text',
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      },
      lastMessage: text,
      lastMessageType: 'text',
    );
  }

  @override
  Future<void> sendImageMessage({
    required List<String> participantIds,
    required String senderId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) {
    return _sendMediaMessage(
      participantIds: participantIds,
      senderId: senderId,
      file: imageFile,
      folder: 'chat_photos',
      extension: 'jpg',
      contentType: 'image/jpeg',
      type: 'image',
      onProgress: onProgress,
    );
  }

  @override
  Future<void> sendVideoMessage({
    required List<String> participantIds,
    required String senderId,
    required File videoFile,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) {
    return _sendMediaMessage(
      participantIds: participantIds,
      senderId: senderId,
      file: videoFile,
      folder: 'chat_videos',
      extension: 'mp4',
      contentType: 'video/mp4',
      type: 'video',
      durationMs: durationMs,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> sendAudioMessage({
    required List<String> participantIds,
    required String senderId,
    required File audioFile,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) {
    return _sendMediaMessage(
      participantIds: participantIds,
      senderId: senderId,
      file: audioFile,
      folder: 'chat_audio',
      extension: 'm4a',
      contentType: 'audio/m4a',
      type: 'audio',
      durationMs: durationMs,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> sendPostMessage({
    required List<String> participantIds,
    required String senderId,
    required String postId,
    required String mediaUrl,
    required bool isVideo,
  }) {
    return _sendMessage(
      participantIds: participantIds,
      senderId: senderId,
      buildMessage: (receiverId) => {
        'senderId': senderId,
        'receiverId': receiverId,
        'type': 'post',
        'postId': postId,
        'mediaUrl': mediaUrl,
        'postIsVideo': isVideo,
        'sentAt': FieldValue.serverTimestamp(),
      },
      lastMessage: '',
      lastMessageType: 'post',
    );
  }

  @override
  Future<void> deleteMessageForMe({required String chatId, required String messageId, required String uid}) {
    return _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deletedFor': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> deleteMessageForEveryone({required String chatId, required String messageId}) async {
    final ref = _chats.doc(chatId).collection('messages').doc(messageId);
    final snap = await ref.get();
    final mediaUrl = snap.data()?['mediaUrl'] as String?;
    await ref.delete();
    if (mediaUrl != null) {
      // Best-effort — a dangling Storage object with no message
      // pointing at it is harmless clutter, not worth failing the
      // (already-applied) delete over.
      try {
        await _storage.refFromURL(mediaUrl).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> forwardMessage({
    required List<String> targetOtherUids,
    required String senderId,
    required MessageType type,
    String? text,
    String? mediaUrl,
    int? durationMs,
    String? postId,
    bool postIsVideo = false,
  }) async {
    final typeName = type.name;
    for (final otherUid in targetOtherUids) {
      await _sendMessage(
        participantIds: [senderId, otherUid],
        senderId: senderId,
        buildMessage: (receiverId) => {
          'senderId': senderId,
          'receiverId': receiverId,
          'type': typeName,
          if (text != null) 'text': text,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (durationMs != null) 'durationMs': durationMs,
          if (postId != null) 'postId': postId,
          if (postId != null) 'postIsVideo': postIsVideo,
          'sentAt': FieldValue.serverTimestamp(),
        },
        lastMessage: type == MessageType.text ? (text ?? '') : '',
        lastMessageType: typeName,
      );
    }
  }

  /// Shared upload + message-write path for image/video/audio: pushes
  /// [file] to `{folder}/{chatId}/{messageId}.{extension}` in Storage,
  /// then writes a message doc of the given [type] pointing at its
  /// download URL. Text stays on its own [sendTextMessage] path since it
  /// has no upload step.
  Future<void> _sendMediaMessage({
    required List<String> participantIds,
    required String senderId,
    required File file,
    required String folder,
    required String extension,
    required String contentType,
    required String type,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final otherUid = participantIds.firstWhere((id) => id != senderId);
    if (await _isBlockedPair(senderId, otherUid)) {
      throw const ChatException(ChatFailure.blocked);
    }

    final chatId = chatIdFor(participantIds);
    final messageRef = _chats.doc(chatId).collection('messages').doc();
    final storagePath = '$folder/$chatId/${messageRef.id}.$extension';
    final storageRef = _storage.ref(storagePath);

    final uploadTask = storageRef.putFile(file, SettableMetadata(contentType: contentType));
    final progressSub = onProgress == null
        ? null
        : uploadTask.snapshotEvents.listen((snap) {
            if (snap.totalBytes > 0) onProgress(snap.bytesTransferred / snap.totalBytes);
          });
    try {
      await uploadTask;
    } finally {
      await progressSub?.cancel();
    }
    final mediaUrl = await storageRef.getDownloadURL();

    await _sendMessage(
      participantIds: participantIds,
      senderId: senderId,
      messageRef: messageRef,
      buildMessage: (receiverId) => {
        'senderId': senderId,
        'receiverId': receiverId,
        'type': type,
        'mediaUrl': mediaUrl,
        if (durationMs != null) 'durationMs': durationMs,
        'sentAt': FieldValue.serverTimestamp(),
      },
      lastMessage: '',
      lastMessageType: type,
    );
  }

  Future<void> _sendMessage({
    required List<String> participantIds,
    required String senderId,
    required Map<String, dynamic> Function(String receiverId) buildMessage,
    required String lastMessage,
    required String lastMessageType,
    DocumentReference<Map<String, dynamic>>? messageRef,
  }) async {
    final chatId = chatIdFor(participantIds);
    final chatRef = _chats.doc(chatId);
    final msgRef = messageRef ?? chatRef.collection('messages').doc();
    final otherUid = participantIds.firstWhere((id) => id != senderId);

    if (await _isBlockedPair(senderId, otherUid)) {
      throw const ChatException(ChatFailure.blocked);
    }

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);

      if (!chatSnap.exists) {
        tx.set(chatRef, {
          'participants': [...participantIds]..sort(),
          'initiatorId': senderId,
          'status': 'pending',
          'lastMessage': lastMessage,
          'lastMessageType': lastMessageType,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSenderId': senderId,
          'unreadCount': {otherUid: 1, senderId: 0},
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = chatSnap.data()!;
        final status = data['status'] as String? ?? 'pending';
        final initiatorId = data['initiatorId'] as String?;
        final lastSenderId = data['lastMessageSenderId'] as String?;

        final canSend = status == 'accepted' ||
            (status == 'pending' && senderId == initiatorId && lastSenderId == null);
        if (!canSend) {
          throw ChatException(
            status == 'declined' ? ChatFailure.requestDeclined : ChatFailure.requestPending,
          );
        }

        final unread = <String, int>{
          for (final entry in ((data['unreadCount'] as Map?) ?? const {}).entries)
            entry.key as String: (entry.value as num).toInt(),
        };
        unread[otherUid] = (unread[otherUid] ?? 0) + 1;

        tx.update(chatRef, {
          'lastMessage': lastMessage,
          'lastMessageType': lastMessageType,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSenderId': senderId,
          'unreadCount': unread,
        });
      }

      tx.set(msgRef, buildMessage(otherUid));
    });
  }

  /// True if either [uidA] has blocked [uidB], or vice versa — reads both
  /// `users/{uid}.blockedUsers` arrays directly rather than going through
  /// `SafetyRepository` to keep this repository's own dependencies self
  /// contained.
  Future<bool> _isBlockedPair(String uidA, String uidB) async {
    final results = await Future.wait([_users.doc(uidA).get(), _users.doc(uidB).get()]);
    final aBlocked = (results[0].data()?['blockedUsers'] as List?)?.cast<String>() ?? const [];
    final bBlocked = (results[1].data()?['blockedUsers'] as List?)?.cast<String>() ?? const [];
    return aBlocked.contains(uidB) || bBlocked.contains(uidA);
  }

  @override
  Future<void> acceptChatRequest(String chatId) {
    return _chats.doc(chatId).update({'status': 'accepted'});
  }

  @override
  Future<void> declineChatRequest(String chatId) {
    return _chats.doc(chatId).update({'status': 'declined'});
  }

  @override
  Future<void> markDelivered(String chatId, String myUid) async {
    final incoming =
        await _chats.doc(chatId).collection('messages').where('senderId', isNotEqualTo: myUid).get();
    final batch = _firestore.batch();
    var touched = false;
    for (final doc in incoming.docs) {
      if (doc.data()['deliveredAt'] == null) {
        batch.update(doc.reference, {'deliveredAt': FieldValue.serverTimestamp()});
        touched = true;
      }
    }
    if (touched) await batch.commit();
  }

  @override
  Future<void> markRead(String chatId, String myUid) async {
    final incoming =
        await _chats.doc(chatId).collection('messages').where('senderId', isNotEqualTo: myUid).get();
    final batch = _firestore.batch();
    for (final doc in incoming.docs) {
      final data = doc.data();
      if (data['readAt'] == null) {
        batch.update(doc.reference, {
          'readAt': FieldValue.serverTimestamp(),
          if (data['deliveredAt'] == null) 'deliveredAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.update(_chats.doc(chatId), {'unreadCount.$myUid': 0});
    await batch.commit();
  }

  @override
  Future<void> setTyping({required String chatId, required String uid, required bool isTyping}) {
    return _chats.doc(chatId).update({'typingUserId': isTyping ? uid : null});
  }

  @override
  Future<void> deleteChat(String chatId, String myUid) {
    // "Delete for me only" isn't modeled yet (no per-user hide flag) —
    // this removes the shared thread outright, matching the MVP's
    // single-thread model. Revisit if per-user history hiding is needed.
    return _chats.doc(chatId).delete();
  }

  Chat _chatFromDoc(String id, Map<String, dynamic> data) {
    return Chat(
      id: id,
      participantIds: (data['participants'] as List?)?.cast<String>() ?? const [],
      initiatorId: data['initiatorId'] as String? ?? '',
      status: _statusFrom(data['status'] as String?),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageType: _typeFrom(data['lastMessageType'] as String?),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      unreadCount: (data['unreadCount'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
          const {},
      typingUserId: data['typingUserId'] as String?,
      pinnedBy: _boolMapFrom(data['pinnedBy']),
      archivedBy: _boolMapFrom(data['archivedBy']),
      mutedBy: _boolMapFrom(data['mutedBy']),
    );
  }

  Map<String, bool> _boolMapFrom(dynamic value) {
    return (value as Map?)?.map((k, v) => MapEntry(k as String, v as bool? ?? false)) ?? const {};
  }

  ChatMessage _messageFromDoc(String id, Map<String, dynamic> data, String chatId) {
    final senderId = data['senderId'] as String? ?? '';
    return ChatMessage(
      id: id,
      senderId: senderId,
      // Falls back to deriving it from the chat id (the two participant
      // uids joined with "_") for messages written before this field
      // existed.
      receiverId: (data['receiverId'] as String?) ??
          chatId.split('_').firstWhere((uid) => uid != senderId, orElse: () => ''),
      text: data['text'] as String?,
      // Falls back to the legacy `imageUrl` field so messages written
      // before the video/audio support existed still render.
      mediaUrl: (data['mediaUrl'] ?? data['imageUrl']) as String?,
      durationMs: (data['durationMs'] as num?)?.toInt(),
      postId: data['postId'] as String?,
      postIsVideo: data['postIsVideo'] as bool? ?? false,
      type: _typeFrom(data['type'] as String?) ?? MessageType.text,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      deletedFor: (data['deletedFor'] as List?)?.cast<String>() ?? const [],
    );
  }

  ChatRequestStatus _statusFrom(String? value) {
    switch (value) {
      case 'accepted':
        return ChatRequestStatus.accepted;
      case 'declined':
        return ChatRequestStatus.declined;
      default:
        return ChatRequestStatus.pending;
    }
  }

  MessageType? _typeFrom(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'text':
        return MessageType.text;
      case 'post':
        return MessageType.post;
      default:
        return null;
    }
  }
}
