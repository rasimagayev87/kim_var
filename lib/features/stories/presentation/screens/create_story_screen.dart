import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/story.dart';
import '../providers/story_providers.dart';

/// Entry point for "add a story": media-type choice → pick from
/// gallery → (video only) 60s duration check → push [CreateStoryScreen]
/// for the visibility choice + share step. Rejects overlong videos
/// outright rather than trimming them — trimming would need a video
/// editing package this app doesn't have, and simply asking the user
/// to pick a shorter clip is the "whichever is easier" option.
Future<void> startCreateStoryFlow(BuildContext context) async {
  final loc = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<StoryMediaType>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.chatAttachmentSheetTitle,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                loc.chatAttachmentImageOption,
                style: AppTextStyles.body.copyWith(fontSize: 15),
              ),
              onTap: () => Navigator.pop(sheetContext, StoryMediaType.image),
            ),
            ListTile(
              leading: const Icon(
                Icons.videocam_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                loc.chatAttachmentVideoOption,
                style: AppTextStyles.body.copyWith(fontSize: 15),
              ),
              onTap: () => Navigator.pop(sheetContext, StoryMediaType.video),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;

  final picker = ImagePicker();
  final XFile? picked = choice == StoryMediaType.image
      ? await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        )
      : await picker.pickVideo(source: ImageSource.gallery);
  if (picked == null || !context.mounted) return;

  final file = File(picked.path);

  if (choice == StoryMediaType.video && await _isVideoTooLong(file)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.storyVideoTooLongMessage)));
    return;
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CreateStoryScreen(file: file, mediaType: choice),
    ),
  );
}

Future<bool> _isVideoTooLong(File file) async {
  final controller = VideoPlayerController.file(file);
  try {
    await controller.initialize();
    return controller.value.duration > const Duration(seconds: 60);
  } catch (_) {
    // Best-effort — if the duration can't be read, don't block the
    // user over it; the Storage rule's 50MB cap is the hard backstop.
    return false;
  } finally {
    await controller.dispose();
  }
}

/// Preview + Paylaş — the second half of [startCreateStoryFlow]. No
/// visibility choice anymore ("Hesab gizliliyi" — see `Story`'s own
/// doc comment); who sees this story is decided entirely by the
/// poster's account-level privacy setting.
class CreateStoryScreen extends ConsumerStatefulWidget {
  final File file;
  final StoryMediaType mediaType;

  const CreateStoryScreen({
    super.key,
    required this.file,
    required this.mediaType,
  });

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  bool _submitting = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == StoryMediaType.video) {
      final controller = VideoPlayerController.file(widget.file);
      _videoController = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller.setLooping(true);
        controller.play();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final loc = AppLocalizations.of(context);

    final storyId = await ref
        .read(storyControllerProvider)
        .createStory(
          media: widget.file,
          mediaType: widget.mediaType,
          onError: () {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(loc.storyShareErrorMessage)));
          },
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (storyId != null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: widget.mediaType == StoryMediaType.image
                ? Image.file(widget.file, fit: BoxFit.contain)
                : (_videoController?.value.isInitialized ?? false)
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const CircularProgressIndicator(color: AppColors.primary),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Text(loc.storyShareButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
