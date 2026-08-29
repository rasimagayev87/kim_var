import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/utils/exif_stripper.dart';
import '../../../safety/data/firebase_safety_repository.dart';
import '../../../safety/domain/safety_repository.dart';
import '../../domain/chat_failure.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore, FirebaseStorage? storage, SafetyRepository? safetyRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _safetyRepository = safetyRepository ?? FirebaseSafetyRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final SafetyRepository _safetyRepository;

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
  }) async {
    // GPS EXIF strip (Düzəliş Prompt 3 / C#43) — chat images are the
    // other highest-priority case (can reveal a home address); video
    // /audio messages are never images, so they're never routed here.
    final stripped = await stripExifIfImage(imageFile);
    return _sendMediaMessage(
      participantIds: participantIds,
      senderId: senderId,
      file: stripped,
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
  Future<void> logCallMessage({
    required List<String> participantIds,
    required String senderId,
    required String callId,
    required String callerId,
    required CallMessageType callMessageType,
    required CallMessageOutcome callOutcome,
    int? callDurationSeconds,
    int? callDataUsageBytes,
  }) {
    final chatId = chatIdFor(participantIds);
    final lastMessage = callOutcome == CallMessageOutcome.missed
        ? (callMessageType == CallMessageType.video ? 'Cavabsız video zəng' : 'Cavabsız səsli zəng')
        : (callMessageType == CallMessageType.video ? 'Video zəng' : 'Səsli zəng');

    return _sendMessage(
      participantIds: participantIds,
      senderId: senderId,
      // Deterministic id (the call's own id, not a fresh auto-id) so a
      // retried/duplicate call to this method for the same call
      // overwrites the same doc instead of logging it twice.
      messageRef: _chats.doc(chatId).collection('messages').doc(callId),
      buildMessage: (receiverId) => {
        'senderId': senderId,
        'receiverId': receiverId,
        'type': 'call',
        'callerId': callerId,
        'callMessageType': callMessageType.name,
        'callOutcome': callOutcome.name,
        if (callDurationSeconds != null) 'callDurationSeconds': callDurationSeconds,
        if (callDataUsageBytes != null) 'callDataUsageBytes': callDataUsageBytes,
        'sentAt': FieldValue.serverTimestamp(),
      },
      lastMessage: lastMessage,
      lastMessageType: 'call',
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
      final chatId = chatIdFor([senderId, otherUid]);
      final messageRef = _chats.doc(chatId).collection('messages').doc();

      // Düzəliş Prompt 10 — a forwarded photo/video/voice message used
      // to reuse the ORIGINAL message's `mediaUrl` verbatim, so both
      // pointed at the exact same Storage object; "delete for everyone"
      // on the original then silently broke this forward's media too
      // (see `deleteMessageForEveryone`'s own doc comment). This gives
      // each forward its OWN independent copy, server-side (no
      // download+re-upload through this device's own bandwidth) —
      // `forwardChatMedia` (Cloud Function) does the actual copy;
      // everything else about this method (block/whoCanMessageMe/
      // pending-accepted checks in `_sendMessage` below) is unchanged.
      final ownMediaUrl = mediaUrl == null
          ? null
          : (await FirebaseFunctions.instance.httpsCallable('forwardChatMedia').call<Map<String, dynamic>>({
              'sourceUrl': mediaUrl,
              'chatId': chatId,
              'messageId': messageRef.id,
            }))
              .data['mediaUrl'] as String;

      await _sendMessage(
        participantIds: [senderId, otherUid],
        senderId: senderId,
        messageRef: messageRef,
        buildMessage: (receiverId) => {
          'senderId': senderId,
          'receiverId': receiverId,
          'type': typeName,
          if (text != null) 'text': text,
          if (ownMediaUrl != null) 'mediaUrl': ownMediaUrl,
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
    if (await _safetyRepository.isBlockedPair(senderId, otherUid)) {
      throw const ChatException(ChatFailure.blocked);
    }

    final chatId = chatIdFor(participantIds);
    final messageRef = _chats.doc(chatId).collection('messages').doc();
    // `{senderId}` segment added (Düzəliş Prompt 3 / RT-8) — was
    // `$folder/$chatId/${messageRef.id}.$extension` with no sender
    // identity anywhere in the path, so `storage.rules`' `allow delete`
    // could only check chat-participant membership (either participant
    // could delete the other's file directly via the Storage SDK).
    // `storage.rules` now requires `request.auth.uid == senderId` on
    // both create and delete, matching the Firestore message doc's own
    // sender-only rules exactly.
    final storagePath = '$folder/$chatId/$senderId/${messageRef.id}.$extension';
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

    if (await _safetyRepository.isBlockedPair(senderId, otherUid)) {
      throw const ChatException(ChatFailure.blocked);
    }

    final chatExistsAlready = (await chatRef.get()).exists;
    if (!chatExistsAlready && !await _canMessage(senderId, otherUid)) {
      throw const ChatException(ChatFailure.notAllowedByRecipient);
    }

    // Only needed for a brand-new chat's `initiatorIsPremium` (see
    // Chat's own doc comment) — skipped on every follow-up message in
    // an existing thread, where this field is never touched again.
    final senderIsPremium =
        chatExistsAlready ? false : (await _users.doc(senderId).get()).data()?['premium'] as bool? ?? false;

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);

      if (!chatSnap.exists) {
        tx.set(chatRef, {
          'participants': [...participantIds]..sort(),
          'initiatorId': senderId,
          'initiatorIsPremium': senderIsPremium,
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

  /// "Kim mənə mesaj göndərə bilər" — only gates starting a brand-new
  /// chat (see the `!chatExistsAlready` check at the only call site);
  /// mirrors `PrivacySettings.whoCanMessageMe` without importing the
  /// privacy feature's domain layer, since this repository only needs
  /// the raw string value off `users/{otherUid}`. `followersOnly` is
  /// enforced against the real `follows` graph — same either-direction
  /// rule as `ProfileVisibility.followersOnly` (see
  /// `FirebaseFollowRepository`'s doc id scheme, mirrored directly here
  /// rather than depending on that repository).
  Future<bool> _canMessage(String senderId, String otherUid) async {
    final otherDoc = await _users.doc(otherUid).get();
    final value = otherDoc.data()?['whoCanMessageMe'] as String? ?? 'everyone';
    if (value != 'followersOnly') return true;

    final follows = _firestore.collection('follows');
    final results = await Future.wait([
      follows.doc('${senderId}_$otherUid').get(),
      follows.doc('${otherUid}_$senderId').get(),
    ]);
    // A still-pending follow request doesn't count — same "absent
    // status = accepted" default as FirebaseFollowRepository, since
    // every edge created before "Hesab gizliliyi" has no status field.
    bool accepted(DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists && doc.data()?['status'] != 'pending';
    return accepted(results[0]) || accepted(results[1]);
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
  Future<void> markRead(String chatId, String myUid, {required bool showReadReceipts}) async {
    final incoming =
        await _chats.doc(chatId).collection('messages').where('senderId', isNotEqualTo: myUid).get();
    final batch = _firestore.batch();
    for (final doc in incoming.docs) {
      final data = doc.data();
      // Voice messages only become "read" via markMessageRead, once the
      // recipient actually presses play — never on blanket chat-open.
      final isVoiceOrCall = data['type'] == 'audio' || data['type'] == 'call';
      if (showReadReceipts && !isVoiceOrCall && data['readAt'] == null) {
        batch.update(doc.reference, {
          'readAt': FieldValue.serverTimestamp(),
          if (data['deliveredAt'] == null) 'deliveredAt': FieldValue.serverTimestamp(),
        });
      } else if (data['deliveredAt'] == null) {
        batch.update(doc.reference, {'deliveredAt': FieldValue.serverTimestamp()});
      }
    }
    batch.update(_chats.doc(chatId), {'unreadCount.$myUid': 0});
    await batch.commit();
  }

  @override
  Future<void> markMessageRead(String chatId, String messageId, String myUid, {required bool showReadReceipts}) async {
    if (!showReadReceipts) return;
    final ref = _chats.doc(chatId).collection('messages').doc(messageId);
    final doc = await ref.get();
    final data = doc.data();
    if (data == null || data['senderId'] == myUid || data['readAt'] != null) return;
    await ref.update({
      'readAt': FieldValue.serverTimestamp(),
      if (data['deliveredAt'] == null) 'deliveredAt': FieldValue.serverTimestamp(),
    });
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
      initiatorIsPremium: data['initiatorIsPremium'] as bool? ?? false,
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
      callerId: data['callerId'] as String?,
      callMessageType: _callMessageTypeFrom(data['callMessageType'] as String?),
      callOutcome: _callOutcomeFrom(data['callOutcome'] as String?),
      callDurationSeconds: (data['callDurationSeconds'] as num?)?.toInt(),
      callDataUsageBytes: (data['callDataUsageBytes'] as num?)?.toInt(),
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
      case 'call':
        return MessageType.call;
      default:
        return null;
    }
  }

  CallMessageType? _callMessageTypeFrom(String? value) {
    switch (value) {
      case 'voice':
        return CallMessageType.voice;
      case 'video':
        return CallMessageType.video;
      default:
        return null;
    }
  }

  CallMessageOutcome? _callOutcomeFrom(String? value) {
    switch (value) {
      case 'missed':
        return CallMessageOutcome.missed;
      case 'completed':
        return CallMessageOutcome.completed;
      default:
        return null;
    }
  }
}
