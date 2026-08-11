import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../post_share/presentation/widgets/post_reel_item.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';

/// Case/dotted-İ-insensitive Azerbaijani search key — own private copy
/// per this codebase's established convention (see `discover_tab.dart`'s
/// `_azVenueSearchKey`), not a shared helper.
String _azSearchKey(String value) {
  return value.replaceAll('İ', 'i').replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase();
}

/// Vertical TikTok/Instagram-Reels-style feed — every user's posts,
/// newest first, one full-screen page per post. [active] mirrors
/// whether the "Lent" tab is the one currently showing in
/// [HomeScreen]'s [IndexedStack] (which keeps every tab mounted, so
/// without this a video would keep decoding/playing in the
/// background on another tab). Each page is a [PostReelItem] — the
/// same widget [PostReelViewerScreen] uses for a profile grid's
/// full-screen swipe-through, so a video looks and behaves identically
/// whether it's reached from here or from a profile.
class FeedTab extends ConsumerStatefulWidget {
  final bool active;

  const FeedTab({super.key, this.active = false});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final _pageController = PageController();
  final _searchController = TextEditingController();
  int _currentPage = 0;
  String _query = '';
  // One shared mute preference for the whole feed (TikTok/Reels-style) —
  // it carries over as you swipe between videos, rather than each video
  // silently resetting to unmuted. Lives here (not per-PostReelItem) so
  // the toggle button can sit in the top bar next to the search field.
  bool _muted = false;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMute() => setState(() => _muted = !_muted);

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _currentPage = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  List<Post> _filterPosts(List<Post> posts) {
    if (_query.trim().isEmpty) return posts;
    final key = _azSearchKey(_query);
    return posts.where((post) {
      if (_azSearchKey(post.caption).contains(key)) return true;
      final profile = ref.watch(publicProfileProvider(post.userId)).valueOrNull;
      if (profile == null) return false;
      return _azSearchKey(profile.name).contains(key) ||
          _azSearchKey(profile.username ?? '').contains(key);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final postsAsync = ref.watch(feedPostsProvider);

    return Container(
      // Deliberately pinned to black regardless of the app's own
      // light theme — a full-bleed Reels/TikTok-style media feed reads
      // as a photo/video viewer, not app chrome (same reasoning as the
      // story viewer and other fullscreen media viewers, which stay
      // black too).
      color: Colors.black,
      child: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return _FeedEmptyState(message: loc.postFeedEmptyMessage);
          }
          final filtered = _filterPosts(posts);
          return Stack(
            children: [
              filtered.isEmpty
                  ? _FeedEmptyState(message: loc.feedSearchNoResultsMessage)
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: filtered.length,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        return PostReelItem(
                          post: filtered[index],
                          isCurrent: widget.active && index == _currentPage,
                          muted: _muted,
                        );
                      },
                    ),
              _FeedTopBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
                muted: _muted,
                onToggleMute: _toggleMute,
                showMuteButton: _currentPage < filtered.length &&
                    filtered[_currentPage].mediaType == PostMediaType.video,
              ),
            ],
          );
        },
        loading: () => const _FeedShimmerLoading(),
        error: (_, _) => _FeedEmptyState(message: loc.postFeedEmptyMessage),
      ),
    );
  }
}

/// "Axtar" field pinned above the feed — a fully transparent pill (just
/// a thin light border) so the photo/video content behind it stays
/// visible, per explicit design direction over the earlier solid-fill
/// version. The mute toggle sits right beside it, same row, only while
/// the current page is a video.
class _FeedTopBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool showMuteButton;

  const _FeedTopBar({
    required this.controller,
    required this.onChanged,
    required this.muted,
    required this.onToggleMute,
    required this.showMuteButton,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    // The app-wide InputDecorationTheme defaults every
                    // TextField to filled:true/fillColor:white (see
                    // app_theme.dart) — without overriding it here, that
                    // solid white fill painted over this field's own
                    // transparent Container, hiding the border entirely
                    // and turning the white icon/hint invisible (white
                    // on white).
                    filled: false,
                    isDense: true,
                    hintText: loc.feedSearchHint,
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (showMuteButton) ...[
              const SizedBox(width: 8),
              MuteToggleButton(muted: muted, onTap: onToggleMute),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedShimmerLoading extends StatelessWidget {
  const _FeedShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF1A1A1A))
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1400.ms, color: const Color(0xFF3A3A3A));
  }
}

class _FeedEmptyState extends StatelessWidget {
  final String message;

  const _FeedEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          // Explicit white — this sits on the feed's pinned-black
          // background (see the Container doc comment above), not an
          // app-chrome surface, so it can't rely on AppTextStyles.caption's
          // default ink color.
          Text(message, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}
