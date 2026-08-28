import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../app_config/presentation/utils/read_only_guard.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../data/repositories/firebase_chat_repository.dart';
import '../../domain/chat_failure.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_audio_message_usecase.dart';
import '../../domain/usecases/send_image_message_usecase.dart';
import '../../domain/usecases/send_text_message_usecase.dart';
import '../../domain/usecases/send_video_message_usecase.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => FirebaseChatRepository());

final sendTextMessageUseCaseProvider = Provider<SendTextMessageUseCase>((ref) {
  return SendTextMessageUseCase(ref.watch(chatRepositoryProvider));
});

final sendImageMessageUseCaseProvider = Provider<SendImageMessageUseCase>((ref) {
  return SendImageMessageUseCase(ref.watch(chatRepositoryProvider));
});

final sendVideoMessageUseCaseProvider = Provider<SendVideoMessageUseCase>((ref) {
  return SendVideoMessageUseCase(ref.watch(chatRepositoryProvider));
});

final sendAudioMessageUseCaseProvider = Provider<SendAudioMessageUseCase>((ref) {
  return SendAudioMessageUseCase(ref.watch(chatRepositoryProvider));
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

/// Deterministic id for the 1:1 chat between the current user and
/// [otherUid] — lets the UI open/watch a conversation before its first
/// message (and thus its chat doc) exists.
String chatIdWith(String otherUid) {
  final uid = _currentUid();
  if (uid == null) return otherUid;
  return FirebaseChatRepository.chatIdFor([uid, otherUid]);
}

// autoDispose so a listener that gets stuck in an error state (a
// transient PERMISSION_DENIED during a token refresh, a network blip,
// etc.) self-heals the next time a screen watches it, instead of
// staying broken for the rest of the app session — StreamProvider
// never retries on its own once its stream errors, and without
// autoDispose the provider instance (and its dead stream) never goes
// away just because nothing is watching it anymore.
final chatsProvider = StreamProvider.autoDispose<List<Chat>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const <Chat>[]);
  return ref.watch(chatRepositoryProvider).watchChats(uid);
});

final chatByIdProvider = StreamProvider.autoDispose.family<Chat?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchChat(chatId);
});

/// Sum of every chat's unread count for the current user — backs the
/// bottom nav's Chat tab badge. Missed-call log messages count toward
/// this the same as any other unread message (see
/// `logCallMessage`/`_sendMessage`'s shared unread-increment path), so
/// there's no separate missed-call counter to maintain: opening a chat
/// (which zeroes its `unreadCount` for this user) clears both unread
/// texts and unseen missed calls in that chat together.
final totalUnreadChatCountProvider = Provider.autoDispose<int>((ref) {
  final uid = _currentUid();
  if (uid == null) return 0;
  final chats = ref.watch(chatsProvider).valueOrNull ?? const <Chat>[];
  return chats.fold(0, (sum, chat) => sum + chat.unreadFor(uid));
});

const _kChatPageSize = 30;

class ChatListState {
  final List<Chat> chats;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const ChatListState({
    this.chats = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  ChatListState copyWith({
    List<Chat>? chats,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return ChatListState(
      chats: chats ?? this.chats,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Merges a realtime first page (instant reordering as new messages
/// arrive, matching WhatsApp) with one-shot older pages loaded on
/// scroll — see [ChatRepository.fetchMoreChats] for why older pages
/// don't need to be realtime themselves. De-duplicates by chat id on
/// every recompute, since a chat present in an older page can receive
/// a new message and reappear in the live first page.
class ChatListController extends StateNotifier<ChatListState> {
  ChatListController(this._ref) : super(const ChatListState()) {
    _subscribeFirstPage();
  }

  final Ref _ref;
  StreamSubscription<List<Chat>>? _firstPageSub;
  List<Chat> _firstPage = const [];
  List<Chat> _olderPages = const [];

  // Firestore's SDK doesn't always finish propagating a just-changed
  // auth context (fresh sign-in right after a sign-out, most commonly)
  // before the very first listener attaches — that one subscription
  // can fail with a transient permission error even though a moment
  // later it would succeed. One silent automatic retry absorbs that
  // race so the user doesn't land on an error screen for it; a second
  // real failure still surfaces normally (via [retry]).
  bool _autoRetried = false;

  void _subscribeFirstPage() {
    final uid = _currentUid();
    if (uid == null) {
      state = state.copyWith(isInitialLoading: false);
      return;
    }
    _firstPageSub = _ref.read(chatRepositoryProvider).watchChats(uid, limit: _kChatPageSize).listen(
      (chats) {
        _firstPage = chats;
        state = state.copyWith(isInitialLoading: false, clearError: true);
        _recompute();
      },
      onError: (Object e, StackTrace st) {
        logError('chat_providers.ChatListController.firstPage', e, st);
        if (!_autoRetried) {
          _autoRetried = true;
          _firstPageSub?.cancel();
          Future<void>.delayed(const Duration(milliseconds: 600), _subscribeFirstPage);
          return;
        }
        state = state.copyWith(isInitialLoading: false, error: e);
      },
    );
  }

  /// Re-subscribes from scratch — used by the retry action on the
  /// error state, since the original listener already terminated.
  void retry() {
    _firstPageSub?.cancel();
    _firstPage = const [];
    _olderPages = const [];
    state = const ChatListState();
    _subscribeFirstPage();
  }

  void _recompute() {
    final seen = <String>{};
    final merged = <Chat>[];
    for (final chat in [..._firstPage, ..._olderPages]) {
      if (seen.add(chat.id)) merged.add(chat);
    }
    merged.sort((a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
    state = state.copyWith(chats: merged);
  }

  Future<void> loadMore() async {
    final uid = _currentUid();
    if (uid == null || state.isLoadingMore || !state.hasMore || state.chats.isEmpty) return;
    final oldest = state.chats.last.lastMessageAt;
    if (oldest == null) return;

    state = state.copyWith(isLoadingMore: true);
    final more = await _ref.read(chatRepositoryProvider).fetchMoreChats(uid, startAfter: oldest, limit: _kChatPageSize);
    _olderPages = [..._olderPages, ...more];
    state = state.copyWith(isLoadingMore: false, hasMore: more.length == _kChatPageSize);
    _recompute();
  }

  Future<void> setPinned(String chatId, bool pinned) async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await _ref.read(chatRepositoryProvider).setPinned(chatId, uid, pinned);
    } catch (e, st) {
      logError('chat_providers.ChatListController.setPinned', e, st);
    }
  }

  Future<void> setArchived(String chatId, bool archived) async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await _ref.read(chatRepositoryProvider).setArchived(chatId, uid, archived);
    } catch (e, st) {
      logError('chat_providers.ChatListController.setArchived', e, st);
    }
  }

  Future<void> setMuted(String chatId, bool muted) async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await _ref.read(chatRepositoryProvider).setMuted(chatId, uid, muted);
    } catch (e, st) {
      logError('chat_providers.ChatListController.setMuted', e, st);
    }
  }

  @override
  void dispose() {
    _firstPageSub?.cancel();
    super.dispose();
  }
}

final chatListControllerProvider = StateNotifierProvider<ChatListController, ChatListState>((ref) {
  // ChatListController isn't autoDispose, so without this watch it's built
  // once and keeps its subscription bound to whatever uid was signed in
  // at that moment — a logout followed by signing into a different
  // account (no full app restart) would otherwise leave both "Hamısı"
  // and "Sorğular" silently empty forever, since the old subscription
  // never re-reads the new uid. Watching authStateProvider makes Riverpod
  // dispose and recreate this controller on every sign-in/sign-out.
  ref.watch(authStateProvider);
  return ChatListController(ref);
});

// autoDispose — same stuck-listener reasoning as chatByIdProvider above.
// Filters out messages the signed-in user chose "Özün üçün sil" on —
// the doc still exists (the other participant's copy is untouched),
// it's just hidden from this one viewer.
final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  final uid = _currentUid();
  return ref.watch(chatRepositoryProvider).watchMessages(chatId).map(
        (messages) => uid == null ? messages : messages.where((m) => !m.deletedFor.contains(uid)).toList(),
      );
});

/// A locally-tracked media send that hasn't (yet, or ever) landed as a
/// real [ChatMessage] in Firestore. This is what lets the composer show
/// `sending` (with live upload progress) and `failed` (with retry) —
/// states that don't exist once a message doc has actually been written,
/// since at that point it's necessarily "sent".
enum PendingMessageStatus { sending, failed }

class PendingOutgoingMessage {
  final String localId;
  final MessageType type;
  final File file;
  final int? durationMs;
  final double progress;
  final PendingMessageStatus status;
  final DateTime createdAt;

  const PendingOutgoingMessage({
    required this.localId,
    required this.type,
    required this.file,
    this.durationMs,
    this.progress = 0,
    this.status = PendingMessageStatus.sending,
    required this.createdAt,
  });

  PendingOutgoingMessage copyWith({double? progress, PendingMessageStatus? status}) {
    return PendingOutgoingMessage(
      localId: localId,
      type: type,
      file: file,
      durationMs: durationMs,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// Drives every chat write (send, accept/decline, receipts, typing,
/// delete). [ChatException]s from a blocked send are both surfaced as
/// error state and rethrown, so callers can either `ref.watch` the
/// state or wrap the call in a try/catch — whichever fits the screen.
class ChatController extends StateNotifier<AsyncValue<void>> {
  ChatController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> sendText({required String otherUid, required String text}) async {
    final uid = _currentUid();
    if (uid == null) return false;
    if (!ensureWritableOrWarn(_ref.read(appConfigProvider))) return false;
    state = const AsyncValue.loading();
    try {
      await _ref.read(sendTextMessageUseCaseProvider).call(
            participantIds: [uid, otherUid],
            senderId: uid,
            text: text,
          );
      state = const AsyncValue.data(null);
      return true;
    } on ChatException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// No upload step — the post's media already lives in Storage, so this
  /// just writes a message doc referencing it. Returns true on success;
  /// swallows failures into a friendly false rather than surfacing a raw
  /// exception, matching most other controller methods here.
  Future<bool> sendPost({
    required String otherUid,
    required String postId,
    required String mediaUrl,
    required bool isVideo,
  }) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(chatRepositoryProvider).sendPostMessage(
            participantIds: [uid, otherUid],
            senderId: uid,
            postId: postId,
            mediaUrl: mediaUrl,
            isVideo: isVideo,
          );
      return true;
    } catch (e, st) {
      logError('chat_providers.ChatController.sendPost', e, st);
      return false;
    }
  }

  /// Writes a call-log message into the chat with [otherUid] once a
  /// call reaches a terminal state — see `CallScreen`'s hang-up path,
  /// its only caller. Never throws; a failed log write shouldn't block
  /// the caller from actually hanging up.
  Future<void> logCall({
    required String otherUid,
    required String callId,
    required String callerId,
    required CallMessageType callMessageType,
    required CallMessageOutcome callOutcome,
    int? callDurationSeconds,
    int? callDataUsageBytes,
  }) async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await _ref.read(chatRepositoryProvider).logCallMessage(
            participantIds: [uid, otherUid],
            senderId: uid,
            callId: callId,
            callerId: callerId,
            callMessageType: callMessageType,
            callOutcome: callOutcome,
            callDurationSeconds: callDurationSeconds,
            callDataUsageBytes: callDataUsageBytes,
          );
    } catch (e, st) {
      logError('chat_providers.ChatController.logCall', e, st);
    }
  }

  Future<bool> sendImage({required String otherUid, required File imageFile}) async {
    final uid = _currentUid();
    if (uid == null) return false;
    state = const AsyncValue.loading();
    try {
      await _ref.read(sendImageMessageUseCaseProvider).call(
            participantIds: [uid, otherUid],
            senderId: uid,
            imageFile: imageFile,
          );
      state = const AsyncValue.data(null);
      return true;
    } on ChatException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Returns true on success. Never throws — any Firestore/network failure
  /// (permission-denied, offline, stale rules mid-deploy, ...) is logged
  /// internally so the request banner can show one friendly message
  /// instead of a raw exception, no matter what went wrong underneath.
  Future<bool> acceptRequest(String chatId) async {
    try {
      await _ref.read(chatRepositoryProvider).acceptChatRequest(chatId);
      return true;
    } catch (e, st) {
      logError('chat_providers.acceptRequest', e, st);
      return false;
    }
  }

  Future<bool> declineRequest(String chatId) async {
    try {
      await _ref.read(chatRepositoryProvider).declineChatRequest(chatId);
      return true;
    } catch (e, st) {
      logError('chat_providers.declineRequest', e, st);
      return false;
    }
  }

  Future<bool> deleteMessageForMe({required String chatId, required String messageId}) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(chatRepositoryProvider).deleteMessageForMe(chatId: chatId, messageId: messageId, uid: uid);
      return true;
    } catch (e, st) {
      logError('chat_providers.deleteMessageForMe', e, st);
      return false;
    }
  }

  Future<bool> deleteMessageForEveryone({required String chatId, required String messageId}) async {
    try {
      await _ref.read(chatRepositoryProvider).deleteMessageForEveryone(chatId: chatId, messageId: messageId);
      return true;
    } catch (e, st) {
      logError('chat_providers.deleteMessageForEveryone', e, st);
      return false;
    }
  }

  /// Forwards [message] into each of [targetOtherUids]' chats with the
  /// caller — up to 5, per the picker sheet's own selection cap.
  Future<bool> forwardMessage({required ChatMessage message, required List<String> targetOtherUids}) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(chatRepositoryProvider).forwardMessage(
            targetOtherUids: targetOtherUids,
            senderId: uid,
            type: message.type,
            text: message.text,
            mediaUrl: message.mediaUrl,
            durationMs: message.durationMs,
            postId: message.postId,
            postIsVideo: message.postIsVideo,
          );
      return true;
    } catch (e, st) {
      logError('chat_providers.forwardMessage', e, st);
      return false;
    }
  }

  Future<void> markDelivered(String chatId) {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    return _ref.read(chatRepositoryProvider).markDelivered(chatId, uid);
  }

  Future<void> markRead(String chatId) {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    return _ref.read(chatRepositoryProvider).markRead(chatId, uid, showReadReceipts: _showReadReceipts());
  }

  /// Triggered by actually pressing play on a voice message — see
  /// `AudioMessagePlayer.onPlayStarted` and `ChatRepository.markMessageRead`.
  Future<void> markMessageRead(String chatId, String messageId) {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    return _ref
        .read(chatRepositoryProvider)
        .markMessageRead(chatId, messageId, uid, showReadReceipts: _showReadReceipts());
  }

  bool _showReadReceipts() => _ref.read(privacySettingsProvider).valueOrNull?.showReadReceipts ?? true;

  Future<void> setTyping(String chatId, bool isTyping) {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    return _ref.read(chatRepositoryProvider).setTyping(chatId: chatId, uid: uid, isTyping: isTyping);
  }

  Future<void> deleteChat(String chatId) {
    final uid = _currentUid();
    if (uid == null) return Future.value();
    return _ref.read(chatRepositoryProvider).deleteChat(chatId, uid);
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  return ChatController(ref);
});

/// Owns every in-flight/failed media upload, keyed by chatId. Kept
/// separate from [ChatController] because its state (progress ticks on
/// every Storage byte chunk) is much chattier and only a handful of
/// widgets — the composer's pending-row — need to rebuild on it.
class PendingMessagesController extends StateNotifier<Map<String, List<PendingOutgoingMessage>>> {
  PendingMessagesController(this._ref) : super(const {});

  final Ref _ref;
  int _counter = 0;

  void _upsert(String chatId, PendingOutgoingMessage message) {
    final list = [...(state[chatId] ?? const <PendingOutgoingMessage>[])];
    final index = list.indexWhere((m) => m.localId == message.localId);
    if (index == -1) {
      list.add(message);
    } else {
      list[index] = message;
    }
    state = {...state, chatId: list};
  }

  void _remove(String chatId, String localId) {
    final list = (state[chatId] ?? const <PendingOutgoingMessage>[])
        .where((m) => m.localId != localId)
        .toList();
    state = {...state, chatId: list};
  }

  Future<void> sendImage({required String chatId, required String otherUid, required File file}) {
    return _send(
      chatId: chatId,
      otherUid: otherUid,
      type: MessageType.image,
      file: file,
      upload: (uid, onProgress) => _ref.read(sendImageMessageUseCaseProvider).call(
        participantIds: [uid, otherUid],
        senderId: uid,
        imageFile: file,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> sendVideo({
    required String chatId,
    required String otherUid,
    required File file,
    int? durationMs,
  }) {
    return _send(
      chatId: chatId,
      otherUid: otherUid,
      type: MessageType.video,
      file: file,
      durationMs: durationMs,
      upload: (uid, onProgress) => _ref.read(sendVideoMessageUseCaseProvider).call(
        participantIds: [uid, otherUid],
        senderId: uid,
        videoFile: file,
        durationMs: durationMs,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> sendAudio({
    required String chatId,
    required String otherUid,
    required File file,
    required int durationMs,
  }) {
    return _send(
      chatId: chatId,
      otherUid: otherUid,
      type: MessageType.audio,
      file: file,
      durationMs: durationMs,
      upload: (uid, onProgress) => _ref.read(sendAudioMessageUseCaseProvider).call(
        participantIds: [uid, otherUid],
        senderId: uid,
        audioFile: file,
        durationMs: durationMs,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _send({
    required String chatId,
    required String otherUid,
    required MessageType type,
    required File file,
    int? durationMs,
    required Future<void> Function(String uid, void Function(double) onProgress) upload,
  }) async {
    final uid = _currentUid();
    if (uid == null) return;

    final localId = 'pending_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    _upsert(
      chatId,
      PendingOutgoingMessage(localId: localId, type: type, file: file, durationMs: durationMs, createdAt: DateTime.now()),
    );

    try {
      await upload(uid, (progress) {
        _upsert(
          chatId,
          PendingOutgoingMessage(
            localId: localId,
            type: type,
            file: file,
            durationMs: durationMs,
            progress: progress,
            createdAt: DateTime.now(),
          ),
        );
      });
      // The Firestore listener will surface the real message within a
      // moment; remove the optimistic placeholder now rather than wait
      // for that round-trip so the bubble doesn't flicker/duplicate.
      _remove(chatId, localId);
    } catch (e, st) {
      logError('chat_providers.PendingMessagesController._send', e, st);
      _upsert(
        chatId,
        PendingOutgoingMessage(
          localId: localId,
          type: type,
          file: file,
          durationMs: durationMs,
          status: PendingMessageStatus.failed,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> retry({required String chatId, required String otherUid, required PendingOutgoingMessage message}) {
    _remove(chatId, message.localId);
    switch (message.type) {
      case MessageType.image:
        return sendImage(chatId: chatId, otherUid: otherUid, file: message.file);
      case MessageType.video:
        return sendVideo(chatId: chatId, otherUid: otherUid, file: message.file, durationMs: message.durationMs);
      case MessageType.audio:
        return sendAudio(
          chatId: chatId,
          otherUid: otherUid,
          file: message.file,
          durationMs: message.durationMs ?? 0,
        );
      case MessageType.text:
      case MessageType.post:
      case MessageType.call:
        // None of these ever become a pending/failed upload — text has
        // no upload step, post-shares go through ChatController.sendPost,
        // and call logs go through ChatController.logCall.
        return Future.value();
    }
  }

  void dismiss(String chatId, String localId) => _remove(chatId, localId);
}

final pendingMessagesProvider =
    StateNotifierProvider<PendingMessagesController, Map<String, List<PendingOutgoingMessage>>>((ref) {
  return PendingMessagesController(ref);
});

final pendingMessagesForChatProvider = Provider.family<List<PendingOutgoingMessage>, String>((ref, chatId) {
  return ref.watch(pendingMessagesProvider.select((state) => state[chatId])) ?? const [];
});
