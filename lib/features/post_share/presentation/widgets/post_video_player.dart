import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../core/widgets/pressable.dart';

/// Feed-card video: shows the clip's first frame (paused) as a
/// thumbnail with a play glyph on top; tapping opens a fullscreen
/// player. Self-contained rather than reusing chat's
/// FullscreenMediaViewer, which is tied to the chat feature's
/// MessageType enum.
///
/// [onTap], when given, replaces the default fullscreen-player
/// navigation — used in the profile feed, where tapping the card
/// should open the post detail screen instead (avoids a nested-gesture
/// conflict with that card's own outer tap target).
class PostVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onTap;

  const PostVideoThumbnail({super.key, required this.videoUrl, this.onTap});

  @override
  State<PostVideoThumbnail> createState() => _PostVideoThumbnailState();
}

class _PostVideoThumbnailState extends State<PostVideoThumbnail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Pressable(
      onTap:
          widget.onTap ??
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _PostVideoFullscreen(videoUrl: widget.videoUrl),
            ),
          ),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            const ColoredBox(color: AppColors.card),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostVideoFullscreen extends StatefulWidget {
  final String videoUrl;

  const _PostVideoFullscreen({required this.videoUrl});

  @override
  State<_PostVideoFullscreen> createState() => _PostVideoFullscreenState();
}

class _PostVideoFullscreenState extends State<_PostVideoFullscreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller
        ..setLooping(true)
        ..play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: controller == null || !controller.value.isInitialized
            ? const CircularProgressIndicator(color: AppColors.primary)
            : Pressable(
                onTap: () => setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                }),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
      ),
    );
  }
}
