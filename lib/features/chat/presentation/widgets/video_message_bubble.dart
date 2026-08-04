import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'fullscreen_media_viewer.dart';

/// In-bubble video preview: shows the clip's first frame with a play
/// glyph on top; tapping opens [FullscreenMediaViewer] for real playback.
/// Deliberately doesn't autoplay inline — keeps the message list light
/// and avoids several videos decoding at once while scrolling.
class VideoMessageBubble extends StatefulWidget {
  final String videoUrl;

  const VideoMessageBubble({super.key, required this.videoUrl});

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullscreenMediaViewer(mediaUrl: widget.videoUrl, type: MessageType.video),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          height: 220,
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
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
