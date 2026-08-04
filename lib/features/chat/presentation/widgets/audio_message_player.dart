import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact play/pause + progress + duration player embedded directly in
/// a voice-message bubble. Colors are passed in rather than hardcoded so
/// the same widget reads correctly on both the "mine" (filled green) and
/// "theirs" (card) bubble backgrounds.
class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int? durationMs;
  final Color accentColor;
  final Color trackColor;
  final Color labelColor;
  final String? avatarUrl;

  const AudioMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.accentColor,
    required this.trackColor,
    required this.labelColor,
    this.durationMs,
    this.avatarUrl,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  late Duration _duration = Duration(milliseconds: widget.durationMs ?? 0);
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  Widget _fallbackAvatar() {
    return ColoredBox(
      color: AppColors.divider,
      child: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
    );
  }

  String _format(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final progress = (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final label = _position > Duration.zero ? _position : _duration;

    return SizedBox(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: (widget.avatarUrl?.isNotEmpty ?? false)
                        ? Image.network(
                            widget.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackAvatar(),
                          )
                        : _fallbackAvatar(),
                  ),
                  // Semi-transparent scrim + play/pause badge, overlaid
                  // on top of the avatar photo — purely visual, doesn't
                  // touch the play/pause/duration logic above.
                  DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), shape: BoxShape.circle),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: widget.trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _format(label),
                  style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: widget.labelColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
