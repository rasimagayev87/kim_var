import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../post_share/presentation/widgets/comments_sheet.dart';
import '../../../post_share/presentation/widgets/post_share_sheet.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';

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
/// background on another tab).
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
  // silently resetting to unmuted. Lives here (not per-_FeedPostView) so
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
                        return _FeedPostView(
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

/// "Axtar" field pinned above the feed, styled as a solid rounded pill
/// (same "premium" language as [_ChatSearchField]/the discover search
/// bar) instead of a bare underline — it needs a visible background of
/// its own since it floats over arbitrary photo/video content. The mute
/// toggle sits right beside it, same row, only while the current page
/// is a video.
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
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
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
              _MuteToggleButton(muted: muted, onTap: onToggleMute),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedPostView extends ConsumerStatefulWidget {
  final Post post;
  final bool isCurrent;
  final bool muted;

  const _FeedPostView({required this.post, required this.isCurrent, required this.muted});

  @override
  ConsumerState<_FeedPostView> createState() => _FeedPostViewState();
}

class _FeedPostViewState extends ConsumerState<_FeedPostView> {
  VideoPlayerController? _controller;
  bool _paused = false;
  bool _fastSpeed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrent && widget.post.mediaType == PostMediaType.video) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _FeedPostView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.mediaType != PostMediaType.video) return;
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _initVideo();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _disposeVideo();
    } else if (widget.muted != oldWidget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _initVideo() async {
    _paused = false;
    _fastSpeed = false;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl));
    _controller = controller;
    try {
      await controller.initialize();
      // The page may have already scrolled past (or a newer controller
      // may have replaced this one) by the time initialize() resolves.
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Non-fatal — the page just shows a shimmer placeholder instead
      // of a frame; swiping away and back retries via didUpdateWidget.
    }
  }

  void _disposeVideo() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _toggleSpeed() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _fastSpeed = !_fastSpeed);
    controller.setPlaybackSpeed(_fastSpeed ? 2.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(),
        // Bottom scrim so the username/caption/action-rail text stays
        // legible over bright media, without the cost of a blur filter.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB3000000)],
              ),
            ),
          ),
        ),
        if (widget.post.mediaType == PostMediaType.video) _VideoTapZones(
          paused: _paused,
          fastSpeed: _fastSpeed,
          onTogglePlayPause: _togglePlayPause,
          onToggleSpeed: _toggleSpeed,
          onDownload: () => showVideoDownloadSheet(context, widget.post),
        ),
        _BottomInfo(post: widget.post),
        _RightActionRail(post: widget.post),
      ],
    );
  }

  Widget _buildMedia() {
    if (widget.post.mediaType == PostMediaType.photo) {
      return Image.network(
        widget.post.mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _FeedShimmerLoading();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

/// Three equal horizontal zones over the video: left/right toggle 2x
/// speed on tap, the middle toggles play/pause on tap and opens the
/// download sheet on long-press. Sits below the mute button/action
/// rail/bottom-info in the stack, so their own tap targets still win.
class _VideoTapZones extends StatelessWidget {
  final bool paused;
  final bool fastSpeed;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSpeed;
  final VoidCallback onDownload;

  const _VideoTapZones({
    required this.paused,
    required this.fastSpeed,
    required this.onTogglePlayPause,
    required this.onToggleSpeed,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onToggleSpeed)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTogglePlayPause,
              onLongPress: onDownload,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (paused)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                    ),
                  if (fastSpeed)
                    Positioned(
                      top: 56,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '2x',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onToggleSpeed)),
        ],
      ),
    );
  }
}

class _MuteToggleButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const _MuteToggleButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(muted ? Icons.volume_off_outlined : Icons.volume_up_outlined, color: Colors.white, size: 18),
      ),
    );
  }
}

class _BottomInfo extends ConsumerWidget {
  final Post post;

  const _BottomInfo({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(publicProfileProvider(post.userId)).valueOrNull;
    final name = (profile?.name.isNotEmpty ?? false) ? profile!.name : loc.defaultUserName;

    return Positioned(
      left: 16,
      right: 88,
      bottom: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 13.5,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Right-edge action rail — avatar, like, comment, share.
class _RightActionRail extends ConsumerWidget {
  final Post post;

  const _RightActionRail({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(post.userId)).valueOrNull;

    return Positioned(
      right: 12,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (!await requireVerified(context, ref)) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileScreen(uid: post.userId)),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: ClipOval(
                child: profile?.photoUrl != null
                    ? Image.network(profile!.photoUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.person_outline, color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _LikeAction(post: post),
          const SizedBox(height: 20),
          _RailAction(
            icon: Icons.mode_comment_outlined,
            count: post.commentsCount,
            onTap: () => showCommentsSheet(context, post.id),
          ),
          const SizedBox(height: 20),
          _RailAction(
            icon: Icons.share_outlined,
            count: null,
            onTap: () => showPostShareOptions(context, post),
          ),
        ],
      ),
    );
  }
}

/// Like heart — red when liked, matching the standard social-app
/// convention already used for comment likes (never the app's cyan
/// accent, which is reserved for interactive-state chrome).
class _LikeAction extends ConsumerWidget {
  final Post post;

  const _LikeAction({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isLiked = ref.watch(isPostLikedByMeProvider(post.id)).valueOrNull ?? false;

    return _RailAction(
      icon: isLiked ? Icons.favorite : Icons.favorite_border,
      count: post.likesCount,
      iconColor: isLiked ? Colors.redAccent : Colors.white,
      onTap: () async {
        if (!await requireVerified(context, ref)) return;
        if (!context.mounted) return;
        final ok = await ref.read(postControllerProvider).toggleLike(post.id, !isLiked);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.postLikeErrorMessage)));
        }
      },
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color iconColor;
  final VoidCallback? onTap;

  const _RailAction({required this.icon, this.count, this.iconColor = Colors.white, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 28, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
          if (count != null && count! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
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

/// Long-press-in-the-middle entry point — offers "Videonu endir",
/// then reuses the same sheet to show download progress and finally a
/// completed state, once the file is written into the phone's own
/// gallery via [Gal.putVideo].
void showVideoDownloadSheet(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _VideoDownloadSheet(post: post),
  );
}

enum _DownloadState { idle, downloading, completed, error }

class _VideoDownloadSheet extends StatefulWidget {
  final Post post;

  const _VideoDownloadSheet({required this.post});

  @override
  State<_VideoDownloadSheet> createState() => _VideoDownloadSheetState();
}

class _VideoDownloadSheetState extends State<_VideoDownloadSheet> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0;

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0;
    });

    File? tempFile;
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) setState(() => _state = _DownloadState.error);
          return;
        }
      }

      final request = http.Request('GET', Uri.parse(widget.post.mediaUrl));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;

      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/kim_var_download_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final sink = tempFile.openWrite();

      var received = 0;
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
        return chunk;
      }).pipe(sink);
      await sink.close();

      await Gal.putVideo(tempFile.path, album: 'Meevima');
      if (mounted) setState(() => _state = _DownloadState.completed);
    } catch (e, st) {
      logError('feed_tab.downloadVideo', e, st);
      if (mounted) setState(() => _state = _DownloadState.error);
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        unawaited(tempFile.delete());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _content(loc),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations loc) {
    switch (_state) {
      case _DownloadState.idle:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined, color: AppColors.primary),
            title: Text(loc.feedDownloadVideoOption, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
            onTap: _startDownload,
          ),
        ];
      case _DownloadState.downloading:
        return [
          CircularProgressIndicator(value: _progress > 0 ? _progress : null, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            loc.feedDownloadInProgressMessage(( _progress * 100).round()),
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
        ];
      case _DownloadState.completed:
        return [
          const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 36),
          const SizedBox(height: 12),
          Text(loc.feedDownloadCompleteMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
        ];
      case _DownloadState.error:
        return [
          const Icon(Icons.error_outline, color: AppColors.error, size: 36),
          const SizedBox(height: 12),
          Text(loc.feedDownloadErrorMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
        ];
    }
  }
}
