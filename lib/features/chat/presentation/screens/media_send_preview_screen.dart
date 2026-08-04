import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';

enum MediaPreviewAction { send, retake }

/// Full-screen review step shown after picking (gallery) or capturing
/// (camera) a photo/video, before it's actually uploaded — the user can
/// back out entirely (system back / close, discarding the file), retake
/// it (camera flow only), or confirm and send it.
class MediaSendPreviewScreen extends StatefulWidget {
  final File file;
  final MessageType type;

  /// When true, the left action reads "Retake" and pops
  /// [MediaPreviewAction.retake] instead of just discarding — used for
  /// the Camera flow so the caller can relaunch the camera. The
  /// Attachment (gallery) flow leaves this false: there's nothing to
  /// "retake", just cancel back to the picker.
  final bool allowRetake;

  const MediaSendPreviewScreen({
    super.key,
    required this.file,
    required this.type,
    this.allowRetake = false,
  });

  @override
  State<MediaSendPreviewScreen> createState() => _MediaSendPreviewScreenState();
}

class _MediaSendPreviewScreenState extends State<MediaSendPreviewScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.type == MessageType.video) {
      final controller = VideoPlayerController.file(widget.file);
      _controller = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Expanded(child: Center(child: _buildPreview())),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, widget.allowRetake ? MediaPreviewAction.retake : null),
                      child: Text(widget.allowRetake ? loc.chatRetakeButton : loc.actionCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, MediaPreviewAction.send),
                      child: Text(loc.chatSendButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.type == MessageType.image) {
      return InteractiveViewer(minScale: 1, maxScale: 4, child: Image.file(widget.file));
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: AppColors.primary);
    }
    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 64),
            ),
          ],
        ),
      ),
    );
  }
}
