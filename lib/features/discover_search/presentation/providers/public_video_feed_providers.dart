import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/domain/repositories/post_repository.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../safety/presentation/providers/safety_providers.dart';

/// Matches `NotificationListController`'s page size — same pagination
/// shape (realtime first page + cursor'd older pages), no reason to
/// pick a different number.
const _kPageSize = 30;

class PublicVideoFeedState {
  final List<Post> videos;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;

  const PublicVideoFeedState({
    this.videos = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  PublicVideoFeedState copyWith({
    List<Post>? videos,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return PublicVideoFeedState(
      videos: videos ?? this.videos,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Discover/search screen's default (empty-query) grid — newest-first
/// video posts from public accounts, across every author. Same
/// realtime-head/cursor'd-tail pagination shape as
/// `NotificationListController`: [PostRepository.watchPublicVideoFeed]
/// stays live for the first page (so a brand-new public video appears
/// without a manual refresh), while [loadMore] pages backward through
/// [PostRepository.fetchMorePublicVideos] one-shot reads.
class PublicVideoFeedController extends StateNotifier<PublicVideoFeedState> {
  PublicVideoFeedController(this._repository)
    : super(const PublicVideoFeedState()) {
    _subscription = _repository
        .watchPublicVideoFeed(limit: _kPageSize)
        .listen(
          (page) {
            _firstPage = page;
            _recompute();
          },
          onError: (Object e, StackTrace st) {
            logError(
              'public_video_feed_providers.PublicVideoFeedController',
              e,
              st,
            );
            state = state.copyWith(isInitialLoading: false);
          },
        );
  }

  final PostRepository _repository;
  StreamSubscription<List<Post>>? _subscription;
  List<Post> _firstPage = const [];
  List<Post> _olderPages = const [];

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.videos.isEmpty) return;

    final oldest = state.videos.last.createdAt;
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await _repository.fetchMorePublicVideos(
        startAfter: oldest,
        limit: _kPageSize,
      );
      _olderPages = [..._olderPages, ...more];
      state = state.copyWith(
        isLoadingMore: false,
        hasMore: more.length == _kPageSize,
      );
      _recompute();
    } catch (e, st) {
      logError(
        'public_video_feed_providers.PublicVideoFeedController.loadMore',
        e,
        st,
      );
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _recompute() {
    final merged = <String, Post>{
      for (final post in [..._firstPage, ..._olderPages]) post.id: post,
    };
    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(videos: list, isInitialLoading: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final publicVideoFeedControllerProvider =
    StateNotifierProvider.autoDispose<
      PublicVideoFeedController,
      PublicVideoFeedState
    >((ref) {
      return PublicVideoFeedController(ref.watch(postRepositoryProvider));
    });

/// [publicVideoFeedControllerProvider]'s own state, minus any author the
/// signed-in user has blocked or been blocked by (Düzəliş Prompt 5 /
/// K-3) — `firestore.rules` can't filter this out of the underlying
/// LIST query itself (see `hiddenAuthorIdsProvider`'s own doc comment),
/// so the feed screen watches THIS instead of the raw controller state.
final visiblePublicVideoFeedProvider =
    Provider.autoDispose<PublicVideoFeedState>((ref) {
      final state = ref.watch(publicVideoFeedControllerProvider);
      final hidden = ref.watch(hiddenAuthorIdsProvider);
      if (hidden.isEmpty) return state;
      return state.copyWith(
        videos: state.videos
            .where((post) => !hidden.contains(post.userId))
            .toList(),
      );
    });
