import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/post.dart';
import '../providers/post_providers.dart';

/// Fullscreen media preview + "Paylaş" — the second half of
/// [startCreatePostFlow]. Pops with `true` once the post is actually
/// shared, so the caller can react (switch to the Profile tab).
class PostPreviewScreen extends ConsumerStatefulWidget {
  final File file;
  final PostMediaType mediaType;

  const PostPreviewScreen({super.key, required this.file, required this.mediaType});

  @override
  ConsumerState<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends ConsumerState<PostPreviewScreen> {
  final _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _submitting = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == PostMediaType.video) {
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
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _progress = 0;
    });
    final loc = AppLocalizations.of(context);

    final ok = await ref.read(postControllerProvider).uploadAndCreatePost(
          file: widget.file,
          mediaType: widget.mediaType,
          caption: _captionController.text.trim(),
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
        );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.postShareErrorMessage)),
      );
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
          onPressed: _submitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: widget.mediaType == PostMediaType.photo
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
                    TextField(
                      controller: _captionController,
                      enabled: !_submitting,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: loc.postCaptionHint,
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black45,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_submitting) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 4,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    ElevatedButton(
                      onPressed: _submitting ? null : _share,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onAccent),
                            )
                          : Text(loc.postShareButton),
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
