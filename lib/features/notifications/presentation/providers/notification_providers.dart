import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firebase_notification_repository.dart';
import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirebaseNotificationRepository(),
);

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

const _kNotificationPageSize = 30;

class NotificationListState {
  final List<AppNotification> notifications;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const NotificationListState({
    this.notifications = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationListState copyWith({
    List<AppNotification>? notifications,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Merges a realtime first page with one-shot older pages loaded on
/// scroll — same shape as [ChatListController], for the same reason:
/// only the page a user is actively looking at needs to be realtime,
/// and de-duplicating by id on every recompute handles an item that
/// was already paged in getting touched by the live first page (e.g.
/// marked read elsewhere).
class NotificationListController extends StateNotifier<NotificationListState> {
  NotificationListController(this._ref) : super(const NotificationListState()) {
    _subscribeFirstPage();
  }

  final Ref _ref;
  StreamSubscription<List<AppNotification>>? _firstPageSub;
  List<AppNotification> _firstPage = const [];
  List<AppNotification> _olderPages = const [];

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
    _firstPageSub = _ref
        .read(notificationRepositoryProvider)
        .watchNotifications(uid, limit: _kNotificationPageSize)
        .listen(
          (notifications) {
            _firstPage = notifications;
            state = state.copyWith(isInitialLoading: false, clearError: true);
            _recompute();
          },
          onError: (Object e, StackTrace st) {
            logError(
              'notification_providers.NotificationListController.firstPage',
              e,
              st,
            );
            if (!_autoRetried) {
              _autoRetried = true;
              _firstPageSub?.cancel();
              Future<void>.delayed(
                const Duration(milliseconds: 600),
                _subscribeFirstPage,
              );
              return;
            }
            state = state.copyWith(isInitialLoading: false, error: e);
          },
        );
  }

  /// Re-subscribes from scratch — used by the retry action on the error
  /// state, since the original listener already terminated.
  void retry() {
    _firstPageSub?.cancel();
    _firstPage = const [];
    _olderPages = const [];
    state = const NotificationListState();
    _subscribeFirstPage();
  }

  void _recompute() {
    final seen = <String>{};
    final merged = <AppNotification>[];
    for (final notification in [..._firstPage, ..._olderPages]) {
      if (seen.add(notification.id)) merged.add(notification);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notifications: merged);
  }

  Future<void> loadMore() async {
    final uid = _currentUid();
    if (uid == null ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.notifications.isEmpty)
      return;
    final oldest = state.notifications.last.createdAt;

    state = state.copyWith(isLoadingMore: true);
    final more = await _ref
        .read(notificationRepositoryProvider)
        .fetchMoreNotifications(
          uid,
          startAfter: oldest,
          limit: _kNotificationPageSize,
        );
    _olderPages = [..._olderPages, ...more];
    state = state.copyWith(
      isLoadingMore: false,
      hasMore: more.length == _kNotificationPageSize,
    );
    _recompute();
  }

  /// Optimistic — flips the local copy to read immediately (the tap
  /// that opens a notification shouldn't wait on a round-trip), then
  /// confirms against Firestore. The realtime first-page listener
  /// reconciles either way, so a failed write simply reverts itself
  /// the next time it fires.
  Future<void> markRead(String notificationId) async {
    final uid = _currentUid();
    if (uid == null) return;

    _firstPage = [
      for (final n in _firstPage) n.id == notificationId ? _asRead(n) : n,
    ];
    _olderPages = [
      for (final n in _olderPages) n.id == notificationId ? _asRead(n) : n,
    ];
    _recompute();

    try {
      await _ref
          .read(notificationRepositoryProvider)
          .markRead(uid, notificationId);
    } catch (e, st) {
      logError(
        'notification_providers.NotificationListController.markRead',
        e,
        st,
      );
    }
  }

  Future<bool> markAllRead() async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(notificationRepositoryProvider).markAllRead(uid);
      return true;
    } catch (e, st) {
      logError(
        'notification_providers.NotificationListController.markAllRead',
        e,
        st,
      );
      return false;
    }
  }

  Future<bool> deleteReadNotifications() async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref
          .read(notificationRepositoryProvider)
          .deleteReadNotifications(uid);
      return true;
    } catch (e, st) {
      logError(
        'notification_providers.NotificationListController.deleteReadNotifications',
        e,
        st,
      );
      return false;
    }
  }

  AppNotification _asRead(AppNotification n) => AppNotification(
    id: n.id,
    type: n.type,
    title: n.title,
    body: n.body,
    imageUrl: n.imageUrl,
    senderId: n.senderId,
    senderName: n.senderName,
    senderPhoto: n.senderPhoto,
    targetId: n.targetId,
    targetType: n.targetType,
    isRead: true,
    createdAt: n.createdAt,
    deepLink: n.deepLink,
    metadata: n.metadata,
  );

  @override
  void dispose() {
    _firstPageSub?.cancel();
    super.dispose();
  }
}

final notificationListControllerProvider =
    StateNotifierProvider<NotificationListController, NotificationListState>((
      ref,
    ) {
      // NotificationListController isn't autoDispose, so without this watch
      // it's built once and keeps its Firestore listener bound to whatever
      // uid was signed in at that moment — signing out and into a different
      // account (no full app restart) would otherwise leave the feed stuck
      // showing the PREVIOUS account's notifications forever (and tapping
      // one would permission-deny, since its targetId/chat/etc. belongs to
      // that other account). Same fix as chatListControllerProvider in
      // chat_providers.dart — watching authStateProvider makes Riverpod
      // dispose and recreate this controller on every sign-in/sign-out.
      ref.watch(authStateProvider);
      return NotificationListController(ref);
    });
