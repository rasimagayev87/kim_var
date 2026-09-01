import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_view.dart';
import '../providers/story_providers.dart';

import '../../../../core/widgets/pressable.dart';

/// How long an image story stays up before auto-advancing. A video
/// story instead runs for its own actual duration (see
/// [_StoryViewerScreenState._startProgress]), same as those apps. Long
/// enough for a text-heavy image to actually be read — press-and-hold
/// (see [_StoryViewerScreenState._onTapDown]) covers anyone who still
/// needs more time.
const _kImageStoryDuration = Duration(seconds: 30);

/// Below this hold duration, a tap-down/tap-up pair is treated as a
/// plain navigation tap (skip back/forward) rather than a pause — long
/// enough that a real hold-to-pause gesture never gets misread as a tap.
const _kTapVsHoldThreshold = Duration(milliseconds: 200);

/// Full-screen viewer for a user's active stories — auto-advances
/// through [stories] as each one's progress bar finishes (Instagram/
/// TikTok-style), and pops back out once the last one finishes. Tap
/// the right half to skip ahead, left half to go back, both resetting
/// progress for the story landed on; closes on stepping past either
/// end, whether that step was a tap or the timer itself running out.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;
  late List<Story> _stories = widget.stories;
  VideoPlayerController? _videoController;
  late final AnimationController _progressController;
  bool _deleting = false;

  /// Bumped on every [_loadVideoIfNeeded] call so a slow, stale
  /// image-precache or video-initialize future that resolves after the
  /// user has already skipped away can detect it's obsolete and no-op
  /// instead of starting the progress bar for the wrong story.
  int _loadGeneration = 0;

  /// True once the current story's media has actually finished loading
  /// (image precached, or video initialized) — the progress bar must
  /// not start until this flips, otherwise it can run out before the
  /// media is even visible on a slow connection.
  bool _mediaReady = false;

  /// Set on [_onTapDown], cleared on release/cancel — both how the
  /// press-and-hold pause is driven and how a quick tap (navigation) is
  /// told apart from a hold (pause/resume), by comparing wall-clock time
  /// between the two.
  DateTime? _pressStartTime;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goTo(_index + 1);
      });
    _loadVideoIfNeeded(_stories[_index]);
    _recordViewIfNeeded(_stories[_index]);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadVideoIfNeeded(Story story) async {
    _videoController?.dispose();
    _videoController = null;
    _progressController.stop();
    final generation = ++_loadGeneration;
    setState(() => _mediaReady = false);

    if (story.mediaType != StoryMediaType.video) {
      try {
        await precacheImage(NetworkImage(story.mediaUrl), context);
      } catch (_) {
        // Falls through — Image.network will still attempt to render
        // and show its own error state; the story shouldn't get stuck.
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _mediaReady = true);
      _startProgress(_kImageStoryDuration);
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(story.mediaUrl),
    );
    _videoController = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _mediaReady = true);
      return;
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() => _mediaReady = true);
    controller.play();
    final videoDuration = controller.value.duration;
    _startProgress(
      videoDuration > Duration.zero ? videoDuration : _kImageStoryDuration,
    );
  }

  void _startProgress(Duration duration) {
    _progressController
      ..stop()
      ..duration = duration
      ..value = 0
      ..forward();
  }

  /// Pauses immediately on press-down — a hold shouldn't wait for a
  /// long-press timeout before the progress bar (and video, if that's
  /// the current story) actually stops, or the read/watch time it's
  /// meant to buy is already half gone by the time it kicks in.
  /// Whether this turns out to be a hold or a quick navigation tap is
  /// only decided on release, in [_onTapUp].
  void _onTapDown(TapDownDetails details) {
    if (!_mediaReady) return;
    _pressStartTime = DateTime.now();
    _progressController.stop();
    _videoController?.pause();
  }

  void _onTapUp(TapUpDetails details) {
    final pressStart = _pressStartTime;
    _pressStartTime = null;
    if (pressStart == null) return;

    // A quick tap navigates, same as before this gesture existed — the
    // brief pause it caused on the way down is invisible at that speed
    // and _goTo restarts progress for whichever story it lands on anyway.
    if (DateTime.now().difference(pressStart) < _kTapVsHoldThreshold) {
      final width = MediaQuery.of(context).size.width;
      if (details.globalPosition.dx < width / 2) {
        _goTo(_index - 1);
      } else {
        _goTo(_index + 1);
      }
      return;
    }

    _progressController.forward();
    _videoController?.play();
  }

  /// The gesture can be cancelled without a matching tap-up (e.g. the
  /// press turns into a scroll/drag) — must still resume, or the story
  /// stays stuck paused with no way to continue.
  void _onTapCancel() {
    if (_pressStartTime == null) return;
    _pressStartTime = null;
    _progressController.forward();
    _videoController?.play();
  }

  /// Viewing your OWN story never counts as a "view" — only records
  /// when someone else opens it, matching the "baxanlar" viewer list's
  /// whole purpose (showing the creator who looked at their story).
  void _recordViewIfNeeded(Story story) {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == story.creatorId) return;
    ref.read(storyControllerProvider).recordView(story.id);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _stories.length) {
      _progressController.stop();
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _index = index);
    _loadVideoIfNeeded(_stories[index]);
    _recordViewIfNeeded(_stories[index]);
  }

  Future<void> _confirmDelete(Story story) async {
    if (_deleting) return;
    final loc = AppLocalizations.of(context);
    _progressController.stop();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          loc.storyDeleteConfirmTitle,
          style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
        ),
        content: Text(
          loc.storyDeleteConfirmMessage,
          style: AppTextStyles.body.copyWith(fontSize: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              loc.actionDelete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _progressController.forward();
      return;
    }

    setState(() => _deleting = true);
    final ok = await ref.read(storyControllerProvider).deleteStory(story.id);
    if (!mounted) return;

    if (!ok) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.storyDeleteErrorMessage)));
      _progressController.forward();
      return;
    }

    final remaining = [..._stories]..removeAt(_index);
    if (remaining.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _stories = remaining;
      _deleting = false;
      if (_index >= _stories.length) _index = _stories.length - 1;
    });
    _loadVideoIfNeeded(_stories[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final story = _stories[_index];
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = myUid != null && myUid == story.creatorId;
    final profile = ref
        .watch(publicProfileProvider(story.creatorId))
        .valueOrNull;
    final creatorName = (profile?.name ?? '').isEmpty
        ? loc.defaultUserName
        : profile!.name;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Center(
              child: story.mediaType == StoryMediaType.image
                  ? (_mediaReady
                        ? AppImage(story.mediaUrl, fit: BoxFit.contain)
                        : const CircularProgressIndicator(
                            color: AppColors.primary,
                          ))
                  : (_videoController?.value.isInitialized ?? false)
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _stories.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                final fraction = i < _index
                                    ? 1.0
                                    : i == _index
                                    ? _progressController.value
                                    : 0.0;
                                return _SegmentBar(fraction: fraction);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.card,
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : null,
                          child: profile?.photoUrl == null
                              ? const Icon(
                                  Icons.person_outline,
                                  color: AppColors.textSecondary,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  creatorName,
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile?.username != null &&
                                  profile!.username!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '@${profile.username}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                formatRelativeTime(story.createdAt, loc),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            onPressed: _deleting
                                ? null
                                : () => _confirmDelete(story),
                            icon: _deleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                  ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwner)
            Positioned(
              left: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ViewersButton(storyId: story.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One Instagram-style progress segment — a static track plus a fill
/// sized to [fraction] (0.0–1.0), left-aligned so it reads as
/// "filling up" rather than growing from the center.
class _SegmentBar extends StatelessWidget {
  final double fraction;

  const _SegmentBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: Colors.white24,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Bottom-left "X baxış" affordance — only the story's own creator can
/// ever see this list ("baxanlar", see `firestore.rules`); shown only
/// when [StoryViewerScreen] is opened by its own owner.
class _ViewersButton extends ConsumerWidget {
  final String storyId;

  const _ViewersButton({required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewCount =
        ref.watch(storyViewsProvider(storyId)).valueOrNull?.length ?? 0;

    return Pressable(
      onTap: () => _showViewersSheet(context, storyId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '$viewCount',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showViewersSheet(BuildContext context, String storyId) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final loc = AppLocalizations.of(sheetContext);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Consumer(
            builder: (context, ref, _) {
              final viewsAsync = ref.watch(storyViewsProvider(storyId));
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.storyViewersTitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  viewsAsync.when(
                    data: (views) => views.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              loc.storyViewersEmptyMessage,
                              style: AppTextStyles.caption,
                            ),
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.5,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: views.length,
                              itemBuilder: (context, index) =>
                                  _ViewerRow(view: views[index]),
                            ),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.4,
                        ),
                      ),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        loc.storyViewersEmptyMessage,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _ViewerRow extends ConsumerWidget {
  final StoryView view;

  const _ViewerRow({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(publicProfileProvider(view.viewerId)).valueOrNull;
    final name = (profile?.name ?? '').isEmpty
        ? loc.defaultUserName
        : profile!.name;

    return InkWell(
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(uid: view.viewerId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.card,
              backgroundImage: profile?.photoUrl != null
                  ? NetworkImage(profile!.photoUrl!)
                  : null,
              child: profile?.photoUrl == null
                  ? const Icon(
                      Icons.person_outline,
                      color: AppColors.textSecondary,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (profile?.username != null &&
                      profile!.username!.isNotEmpty)
                    Text(
                      '@${profile.username}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                ],
              ),
            ),
            Text(
              DateFormat('HH:mm').format(view.viewedAt),
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
