import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_view.dart';
import '../providers/story_providers.dart';

/// Full-screen viewer for the signed-in user's OWN active stories —
/// tap the right half to advance, left half to go back (closes on
/// stepping past either end), matching the standard tap-to-navigate
/// story-viewer interaction rather than swipe paging. A thin segmented
/// bar at the top shows position among [stories].
class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewerScreen({super.key, required this.stories, this.initialIndex = 0});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late int _index = widget.initialIndex;
  late List<Story> _stories = widget.stories;
  VideoPlayerController? _videoController;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadVideoIfNeeded(_stories[_index]);
    _recordViewIfNeeded(_stories[_index]);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _loadVideoIfNeeded(Story story) {
    _videoController?.dispose();
    _videoController = null;
    if (story.mediaType != StoryMediaType.video) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
    });
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
      Navigator.pop(context);
      return;
    }
    setState(() => _index = index);
    _loadVideoIfNeeded(_stories[index]);
    _recordViewIfNeeded(_stories[index]);
  }

  Future<void> _confirmDelete(Story story) async {
    if (_deleting) return;
    final loc = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.storyDeleteConfirmTitle, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
        content: Text(loc.storyDeleteConfirmMessage, style: AppTextStyles.body.copyWith(fontSize: 14.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.actionDelete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await ref.read(storyControllerProvider).deleteStory(story.id);
    if (!mounted) return;

    if (!ok) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.storyDeleteErrorMessage)));
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
    final story = _stories[_index];
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = myUid != null && myUid == story.creatorId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapUp: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 2) {
                _goTo(_index - 1);
              } else {
                _goTo(_index + 1);
              }
            },
            child: Center(
              child: story.mediaType == StoryMediaType.image
                  ? Image.network(story.mediaUrl, fit: BoxFit.contain)
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < _stories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: i <= _index ? AppColors.primary : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: SafeArea(
              child: Row(
                children: [
                  if (isOwner)
                    IconButton(
                      onPressed: _deleting ? null : () => _confirmDelete(story),
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
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

/// Bottom-left "X baxış" affordance — only the story's own creator can
/// ever see this list ("baxanlar", see `firestore.rules`), which this
/// screen only ever shows to its owner anyway (it's reached solely
/// from the self-profile ring). Note: since nothing yet lets OTHER
/// users open someone else's story, no view ever actually gets
/// recorded — this button/sheet is real and will start showing real
/// viewers the moment a "watch someone else's story" entry point
/// exists elsewhere in the app.
class _ViewersButton extends ConsumerWidget {
  final String storyId;

  const _ViewersButton({required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewCount = ref.watch(storyViewsProvider(storyId)).valueOrNull?.length ?? 0;

    return GestureDetector(
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
            const Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('$viewCount', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  Text(loc.storyViewersTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  viewsAsync.when(
                    data: (views) => views.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(loc.storyViewersEmptyMessage, style: AppTextStyles.caption),
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: views.length,
                              itemBuilder: (context, index) => _ViewerRow(view: views[index]),
                            ),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4)),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(loc.storyViewersEmptyMessage, style: AppTextStyles.caption),
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
    final name = (profile?.name ?? '').isEmpty ? loc.defaultUserName : profile!.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.card,
            backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
            child: profile?.photoUrl == null
                ? const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: AppTextStyles.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500)),
          ),
          Text(DateFormat('HH:mm').format(view.viewedAt), style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
