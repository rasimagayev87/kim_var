import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_follow_repository.dart';
import '../../domain/entities/follow_edge.dart';
import '../../domain/repositories/follow_repository.dart';

final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FirebaseFollowRepository(),
);

/// How many users follow [uid] — works for the signed-in user's own
/// profile (`profile_tab.dart`) or anyone else's (`user_profile_screen.dart`).
final followersCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  uid,
) {
  return ref.watch(followRepositoryProvider).watchFollowersCount(uid);
});

/// How many users [uid] follows.
final followingCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  uid,
) {
  return ref.watch(followRepositoryProvider).watchFollowingCount(uid);
});

/// Whether the signed-in user follows [otherUid] — ACCEPTED only.
/// Drives the Follow/Following button state, and (via `AccountPrivacy
/// .private`) whether their media/stories are visible.
final isFollowingProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  otherUid,
) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(false);
  return ref
      .watch(followRepositoryProvider)
      .watchIsFollowing(followerId: myUid, followeeId: otherUid);
});

/// Whether the signed-in user has an outstanding, not-yet-accepted
/// request to follow [otherUid] — drives the "İstək göndərildi" button
/// state on a `private` account's profile.
final isPendingFollowRequestProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, otherUid) {
      final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) return Stream.value(false);
      return ref
          .watch(followRepositoryProvider)
          .watchIsPending(followerId: myUid, followeeId: otherUid);
    });

/// Whether [otherUid] has sent the signed-in user a still-pending
/// follow request — true here means `UserProfileScreen` should show
/// Accept/Decline instead of the normal Follow button (this is exactly
/// the profile a `followRequest` notification's "profile" targetType
/// deep-links to).
final incomingFollowRequestProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, otherUid) {
      final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) return Stream.value(false);
      return ref
          .watch(followRepositoryProvider)
          .watchIsPending(followerId: otherUid, followeeId: myUid);
    });

class FollowController {
  FollowController(this._ref);

  final Ref _ref;

  /// Returns true on success. Never throws — matches every other
  /// controller in this app (see `FriendController.sendRequest`):
  /// failures are logged internally so the button can show one
  /// friendly message instead of a raw exception.
  ///
  /// [isCurrentlyFollowing]/[isCurrentlyPending] decide unfollow vs.
  /// cancel-request vs. new-follow; [otherAccountIsPrivate] decides
  /// whether a brand-new edge starts `pending` (needs the followee's
  /// approval) or `accepted` (instant) — see `AccountPrivacy`.
  Future<bool> toggleFollow({
    required String otherUid,
    required bool isCurrentlyFollowing,
    required bool isCurrentlyPending,
    required bool otherAccountIsPrivate,
  }) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;

    try {
      if (isCurrentlyFollowing || isCurrentlyPending) {
        await _ref
            .read(followRepositoryProvider)
            .unfollow(followerId: myUid, followeeId: otherUid);
      } else {
        await _ref
            .read(followRepositoryProvider)
            .follow(
              followerId: myUid,
              followeeId: otherUid,
              requiresApproval: otherAccountIsPrivate,
            );
      }
      return true;
    } catch (e, st) {
      logError('follow_providers.toggleFollow', e, st);
      return false;
    }
  }

  /// Returns true on success (logged internally on failure). [otherUid]
  /// is the REQUESTER — the profile `UserProfileScreen` is currently
  /// showing Accept/Decline for.
  Future<bool> acceptFollowRequest(String otherUid) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    try {
      await _ref
          .read(followRepositoryProvider)
          .acceptFollowRequest(followerId: otherUid, followeeId: myUid);
      return true;
    } catch (e, st) {
      logError('follow_providers.acceptFollowRequest', e, st);
      return false;
    }
  }

  Future<bool> declineFollowRequest(String otherUid) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    try {
      await _ref
          .read(followRepositoryProvider)
          .declineFollowRequest(followerId: otherUid, followeeId: myUid);
      return true;
    } catch (e, st) {
      logError('follow_providers.declineFollowRequest', e, st);
      return false;
    }
  }

  /// "Çıxart" — [otherUid] stops being one of the SIGNED-IN user's
  /// followers. [otherUid] here is the FOLLOWER being removed, not
  /// someone the signed-in user follows.
  Future<bool> removeFollower(String otherUid) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return false;
    try {
      await _ref
          .read(followRepositoryProvider)
          .removeFollower(followerId: otherUid, followeeId: myUid);
      return true;
    } catch (e, st) {
      logError('follow_providers.removeFollower', e, st);
      return false;
    }
  }
}

final followControllerProvider = Provider<FollowController>(
  (ref) => FollowController(ref),
);

/// One page of a followers/following list — [items] newest-edge-first,
/// [hasMore] driven by "did the last page come back full" (same
/// heuristic `NotificationListController` uses). [hasError] surfaces a
/// failed fetch (e.g. a transient network drop) as a distinct empty
/// state rather than leaving the screen spinning forever.
class FollowListState {
  final List<FollowEdge> items;
  final bool initialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;

  const FollowListState({
    this.items = const [],
    this.initialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
  });

  FollowListState copyWith({
    List<FollowEdge>? items,
    bool? initialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
  }) {
    return FollowListState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// One class serving both the Followers and Following tabs of
/// `FollowListScreen` — which list it pages through is decided
/// entirely by the [fetchPage] closure it's constructed with (see
/// `followersListControllerProvider`/`followingListControllerProvider`
/// below), so the pagination logic itself isn't duplicated per tab.
class FollowListController extends StateNotifier<FollowListState> {
  FollowListController(this._fetchPage) : super(const FollowListState()) {
    _loadFirstPage();
  }

  static const _pageSize = 30;
  final Future<List<FollowEdge>> Function({DateTime? startAfter, int limit})
  _fetchPage;

  Future<void> _loadFirstPage() async {
    try {
      final page = await _fetchPage(limit: _pageSize);
      state = FollowListState(
        items: page,
        initialLoading: false,
        hasMore: page.length == _pageSize,
      );
    } catch (e, st) {
      logError('FollowListController._loadFirstPage', e, st);
      state = const FollowListState(
        initialLoading: false,
        hasMore: false,
        hasError: true,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.initialLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.items.isEmpty)
      return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _fetchPage(
        startAfter: state.items.last.createdAt,
        limit: _pageSize,
      );
      state = state.copyWith(
        items: [...state.items, ...page],
        isLoadingMore: false,
        hasMore: page.length == _pageSize,
      );
    } catch (e, st) {
      logError('FollowListController.loadMore', e, st);
      // Leave the already-loaded items in place; just stop trying to
      // page further so the list doesn't retry-loop against whatever
      // just failed.
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    }
  }

  /// Drops [uid] from the currently-shown page right after a
  /// successful remove-follower/unfollow on OWN list — a real
  /// server-side re-fetch would show the same result, this just
  /// avoids the round-trip.
  void removeLocally(String uid) {
    state = state.copyWith(
      items: state.items.where((e) => e.uid != uid).toList(),
    );
  }
}

final followersListControllerProvider = StateNotifierProvider.autoDispose
    .family<FollowListController, FollowListState, String>((ref, uid) {
      final repo = ref.watch(followRepositoryProvider);
      return FollowListController(
        ({startAfter, limit = 30}) =>
            repo.fetchFollowersPage(uid, startAfter: startAfter, limit: limit),
      );
    });

final followingListControllerProvider = StateNotifierProvider.autoDispose
    .family<FollowListController, FollowListState, String>((ref, uid) {
      final repo = ref.watch(followRepositoryProvider);
      return FollowListController(
        ({startAfter, limit = 30}) =>
            repo.fetchFollowingPage(uid, startAfter: startAfter, limit: limit),
      );
    });
