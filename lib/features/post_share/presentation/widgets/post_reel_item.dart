import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../data/post_media_cache.dart';
import '../../domain/entities/post.dart';
import '../providers/post_providers.dart';
import 'comments_sheet.dart';
import 'post_share_sheet.dart';

import '../../../../core/widgets/pressable.dart';

/// One full-screen Reels/TikTok-style page for a single [Post] — video
/// (autoplaying, looping, tap zones for play/pause + long-press-hold
/// 2x speed) or photo, plus the bottom name/caption and right-edge
/// like/comment/share rail. This is the single source of truth for
/// that experience: both the Lent tab ([FeedTab], a [PageView] over
/// every user's posts) and [PostReelViewerScreen] (a [PageView] over
/// one user's own posts, pushed from their profile grid) wrap this
/// same widget rather than each having their own copy — a video
/// opened from a profile grid must look and behave exactly like one
/// swiped past in Lent.
class PostReelItem extends ConsumerStatefulWidget {
  final Post post;
  final bool isCurrent;
  final bool muted;

  const PostReelItem({
    super.key,
    required this.post,
    required this.isCurrent,
    required this.muted,
  });

  @override
  ConsumerState<PostReelItem> createState() => _PostReelItemState();
}

class _PostReelItemState extends ConsumerState<PostReelItem> {
  VideoPlayerController? _controller;
  bool _paused = false;
  bool _fastSpeed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrent) {
      if (widget.post.mediaType == PostMediaType.video) {
        _initVideo();
      } else {
        _cacheMediaInBackground();
      }
    }
  }

  @override
  void didUpdateWidget(covariant PostReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.mediaType != PostMediaType.video) {
      if (widget.isCurrent && !oldWidget.isCurrent) _cacheMediaInBackground();
      return;
    }
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _initVideo();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _disposeVideo();
    } else if (widget.muted != oldWidget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  /// Fire-and-forget — starts (or joins an already-running) download
  /// into [PostMediaCache] the instant this post becomes the one on
  /// screen, so by the time the user reaches "Paylaş" the file is
  /// typically already local and the native share sheet opens with no
  /// perceptible delay. Errors here are silent: `showPostShareOptions`
  /// falls back to downloading on demand if this never finished.
  void _cacheMediaInBackground() {
    final extension = widget.post.mediaType == PostMediaType.video
        ? 'mp4'
        : 'jpg';
    unawaited(
      PostMediaCache.getOrDownload(widget.post.mediaUrl, extension: extension),
    );
  }

  Future<void> _initVideo() async {
    _paused = false;
    _fastSpeed = false;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      // The page may have already scrolled past (or a newer controller
      // may have replaced this one) by the time initialize() resolves.
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      // Otherwise the phone's own screen-timeout kicks in mid-playback
      // (a video has no touch input to reset it, unlike scrolling a
      // feed) — same "keep screen on while actively playing" behavior
      // every other video app has.
      unawaited(WakelockPlus.enable());
      if (mounted) setState(() {});
      _cacheMediaInBackground();
    } catch (_) {
      // Non-fatal — the page just shows a shimmer placeholder instead
      // of a frame; swiping away and back retries via didUpdateWidget.
    }
  }

  void _disposeVideo() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    unawaited(WakelockPlus.disable());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      controller.pause();
      unawaited(WakelockPlus.disable());
    } else {
      controller.play();
      unawaited(WakelockPlus.enable());
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
        if (widget.post.mediaType == PostMediaType.video)
          _VideoTapZones(
            paused: _paused,
            fastSpeed: _fastSpeed,
            onTogglePlayPause: _togglePlayPause,
            onToggleSpeed: _toggleSpeed,
            onDownload: () => showVideoDownloadSheet(context, widget.post),
          ),
        if (widget.post.mediaType == PostMediaType.video && _controller != null)
          _VideoProgressBar(controller: _controller!),
        _BottomInfo(post: widget.post),
        _RightActionRail(post: widget.post),
      ],
    );
  }

  Widget _buildMedia() {
    if (widget.post.mediaType == PostMediaType.photo) {
      // `contain` on a black background, never `cover` — a rectangular
      // (non-square) photo must show in full, matching how the video
      // branch below already letterboxes landscape/square clips
      // instead of cropping them.
      return Container(
        color: Colors.black,
        child: AppImage(
          widget.post.mediaUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _MediaShimmer();
    }

    // Portrait video (the common case — this is a Reels/TikTok-style
    // feed) fills the screen edge-to-edge; cropping a few pixels off
    // the sides is unnoticeable. Landscape/square video gets
    // letterboxed (contain, black bars) instead — covering it would
    // crop the top/bottom of a 16:9 clip, cutting off real content.
    final aspectRatio = controller.value.aspectRatio;
    if (aspectRatio < 1) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _MediaShimmer extends StatelessWidget {
  const _MediaShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF1A1A1A))
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1400.ms, color: const Color(0xFF3A3A3A));
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
          // Görünməz toxunma zonası — animasiya ediləcək məzmun yoxdur.
          // Görünməz toxunma zonası — animasiya ediləcək məzmun yoxdur,
          // ona görə `Pressable` deyil.
          Expanded(child: GestureDetector(onTap: onToggleSpeed)),
          Expanded(
            child: Pressable(
              onTap: onTogglePlayPause,
              onLongPress: onDownload,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (paused)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0x66000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  if (fastSpeed)
                    Positioned(
                      top: 56,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '2x',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Görünməz toxunma zonası — animasiya ediləcək məzmun yoxdur.
          // Görünməz toxunma zonası — animasiya ediləcək məzmun yoxdur,
          // ona görə `Pressable` deyil.
          Expanded(child: GestureDetector(onTap: onToggleSpeed)),
        ],
      ),
    );
  }
}

/// Scrubbable progress bar + "0:14 / 0:42" position/duration readout,
/// pinned across the bottom of the video. Rebuilds on every
/// [VideoPlayerController] value tick (video_player emits these
/// continuously during playback) rather than polling on a timer.
/// Dragging seeks live — [VideoPlayerController.seekTo] is cheap
/// enough to call on every [Slider.onChanged], not just on release.
class _VideoProgressBar extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoProgressBar({required this.controller});

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 14,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final duration = value.duration;
          if (duration <= Duration.zero) return const SizedBox.shrink();
          final position = value.position > duration
              ? duration
              : value.position;

          return Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    value: position.inMilliseconds.toDouble().clamp(
                      0,
                      duration.inMilliseconds.toDouble(),
                    ),
                    onChanged: (ms) =>
                        controller.seekTo(Duration(milliseconds: ms.round())),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_format(position)} / ${_format(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Top-bar mute toggle — shared by [FeedTab]'s search-row top bar and
/// [PostReelViewerScreen]'s back/owner-menu top bar.
class MuteToggleButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const MuteToggleButton({super.key, required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          color: Colors.white,
          size: 18,
        ),
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
    final name = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
        : loc.defaultUserName;

    return Positioned(
      left: 16,
      right: 88,
      bottom: 54,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
              if (profile?.username != null &&
                  profile!.username!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '@${profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ],
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
    final isOwnPost = fb.FirebaseAuth.instance.currentUser?.uid == post.userId;

    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(
              onTap: () async {
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(uid: post.userId),
                  ),
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
                      ? AppImage(
                          profile!.photoUrl!,
                          thumbnail: true,
                          fit: BoxFit.cover,
                        )
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
            if (!isOwnPost) ...[
              const SizedBox(height: 20),
              _RepostAction(post: post),
            ],
          ],
        ),
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
    final isLiked =
        ref.watch(isPostLikedByMeProvider(post.id)).valueOrNull ?? false;

    return _RailAction(
      icon: isLiked ? Icons.favorite : Icons.favorite_border,
      count: post.likesCount,
      iconColor: isLiked ? Colors.redAccent : Colors.white,
      onTap: () async {
        if (!context.mounted) return;
        final ok = await ref
            .read(postControllerProvider)
            .toggleLike(post.id, !isLiked);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.postLikeErrorMessage)));
        }
      },
    );
  }
}

/// Repost toggle — cyan (the app's own accent) rather than like's red,
/// so the two read as distinct actions at a glance. Reposting adds
/// [post] to the reposter's own "Repostlar" profile tab
/// ([userRepostedPostsProvider]); it never touches the original post's
/// own owner/counts. `_RightActionRail` only ever mounts this for
/// someone else's post — reposting your own is nonsensical, and
/// `firestore.rules`' `users/{uid}/reposts/{postId}` create rule
/// rejects it server-side too, so this isn't just a UI nicety.
class _RepostAction extends ConsumerWidget {
  final Post post;

  const _RepostAction({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isReposted =
        ref.watch(isPostRepostedByMeProvider(post.id)).valueOrNull ?? false;

    return _RailAction(
      icon: Icons.repeat_rounded,
      count: null,
      iconColor: isReposted ? AppColors.primary : Colors.white,
      onTap: () async {
        if (!context.mounted) return;
        final ok = await ref
            .read(postControllerProvider)
            .toggleRepost(post.id, !isReposted);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.postRepostErrorMessage)));
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

  const _RailAction({
    required this.icon,
    this.count,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 28,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
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

/// Long-press-in-the-middle entry point — offers "Videonu endir",
/// then reuses the same sheet to show download progress and finally a
/// completed state, once the file is written into the phone's own
/// gallery via [Gal.putVideo].
void showVideoDownloadSheet(BuildContext context, Post post) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) setState(() => _state = _DownloadState.error);
          return;
        }
      }

      // Same shared cache the media viewer/share-sheet use — if this
      // post is already playing, [PostMediaCache] may well have
      // already finished (or be mid-way through) downloading it, so
      // this often resolves instantly instead of starting over.
      final file = await PostMediaCache.getOrDownload(
        widget.post.mediaUrl,
        extension: 'mp4',
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );

      // Copied into the gallery, not moved — the cache file stays put
      // for `PostMediaCache`'s own callers (share sheet, background
      // pre-cache) and follows normal cache eviction, never deleted
      // here just because this one flow is done with it.
      await Gal.putVideo(file.path, album: 'PeakPin');
      if (mounted) setState(() => _state = _DownloadState.completed);
    } catch (e, st) {
      logError('post_reel_item.downloadVideo', e, st);
      if (mounted) setState(() => _state = _DownloadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: _content(loc)),
      ),
    );
  }

  List<Widget> _content(AppLocalizations loc) {
    switch (_state) {
      case _DownloadState.idle:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.download_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              loc.feedDownloadVideoOption,
              style: AppTextStyles.body.copyWith(fontSize: 15.5),
            ),
            onTap: _startDownload,
          ),
        ];
      case _DownloadState.downloading:
        return [
          CircularProgressIndicator(
            value: _progress > 0 ? _progress : null,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            loc.feedDownloadInProgressMessage((_progress * 100).round()),
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
        ];
      case _DownloadState.completed:
        return [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            loc.feedDownloadCompleteMessage,
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
        ];
      case _DownloadState.error:
        return [
          const Icon(Icons.error_outline, color: AppColors.error, size: 36),
          const SizedBox(height: 12),
          Text(
            loc.feedDownloadErrorMessage,
            style: AppTextStyles.body.copyWith(fontSize: 14.5),
          ),
        ];
    }
  }
}
