import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';

/// Full-bleed black viewer opened by tapping an image or video bubble.
/// Images support pinch-zoom; video gets basic tap-to-toggle playback.
class FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final MessageType type;

  const FullscreenMediaViewer({super.key, required this.mediaUrl, required this.type});

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  VideoPlayerController? _controller;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == MessageType.video) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
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

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) messenger.showSnackBar(SnackBar(content: Text(loc.chatMediaDownloadErrorMessage)));
          return;
        }
      }

      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      if (widget.type == MessageType.image) {
        await Gal.putImageBytes(response.bodyBytes, album: 'PeakPin');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/peakpin_${DateTime.now().microsecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putVideo(file.path, album: 'PeakPin');
        unawaited(file.delete().catchError((_) => file));
      }

      if (mounted) messenger.showSnackBar(SnackBar(content: Text(loc.chatMediaDownloadedMessage)));
    } catch (e, st) {
      logError('fullscreen_media_viewer._download', e, st);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(loc.chatMediaDownloadErrorMessage)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: loc.chatMediaDownloadTooltip,
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: widget.type == MessageType.image
            ? InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AppImage(widget.mediaUrl, fit: BoxFit.contain),
              )
            : _buildVideo(),
      ),
    );
  }

  Widget _buildVideo() {
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
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 72),
            ),
          ],
        ),
      ),
    );
  }
}
