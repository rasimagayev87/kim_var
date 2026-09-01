import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/navigation/deep_link_handler.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/call_session.dart';
import '../providers/active_call_controller.dart';
import '../screens/call_screen.dart';

import '../../../../core/widgets/pressable.dart';

/// Mounted once at the app root (see `main.dart`'s `MaterialApp.builder`)
/// so it floats above whatever route is currently showing — the whole
/// point of minimizing a call is that the rest of the app underneath
/// stays fully usable while this stays visible regardless of how deep
/// the user navigates. Renders nothing when there's no active/minimized
/// call, so it's a zero-cost no-op the overwhelming majority of the
/// time.
class CallPipOverlay extends ConsumerWidget {
  const CallPipOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(activeCallControllerProvider);
    if (!call.hasActiveCall || !call.minimized) return const SizedBox.shrink();
    return _DraggablePipBubble(call: call);
  }
}

class _DraggablePipBubble extends ConsumerStatefulWidget {
  final ActiveCallUiState call;

  const _DraggablePipBubble({required this.call});

  @override
  ConsumerState<_DraggablePipBubble> createState() =>
      _DraggablePipBubbleState();
}

class _DraggablePipBubbleState extends ConsumerState<_DraggablePipBubble>
    with SingleTickerProviderStateMixin {
  static const _width = 120.0;
  static const _height = 168.0;
  static const _margin = 12.0;

  late final AnimationController _snapController;
  Offset? _topLeft;
  Offset? _dragTopLeft;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _restore() {
    ref.read(activeCallControllerProvider.notifier).restore();
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.call.callId!,
          otherUid: widget.call.otherUid!,
          type: widget.call.type!,
          isCaller: widget.call.isCaller,
        ),
      ),
    );
  }

  void _snapToNearestCorner(Size screenSize) {
    final start = _dragTopLeft ?? _topLeft!;
    final centerX = start.dx + _width / 2;
    final centerY = start.dy + _height / 2;
    final targetX = centerX < screenSize.width / 2
        ? _margin
        : screenSize.width - _width - _margin;
    final targetY = centerY < screenSize.height / 2
        ? _margin
        : screenSize.height - _height - _margin;
    final target = Offset(
      targetX,
      targetY.clamp(_margin, screenSize.height - _height - _margin),
    );

    final animation = Tween<Offset>(
      begin: start,
      end: target,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    void listener() => setState(() => _dragTopLeft = animation.value);
    animation.addListener(listener);
    _snapController.forward(from: 0).whenComplete(() {
      animation.removeListener(listener);
      setState(() {
        _topLeft = target;
        _dragTopLeft = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _topLeft ??= Offset(size.width - _width - _margin, size.height * 0.35);
    final position = _dragTopLeft ?? _topLeft!;
    final clamped = Offset(
      position.dx.clamp(_margin, size.width - _width - _margin),
      position.dy.clamp(_margin, size.height - _height - _margin),
    );

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      width: _width,
      height: _height,
      child: GestureDetector(
        onTap: _restore,
        onPanUpdate: (details) =>
            setState(() => _dragTopLeft = clamped + details.delta),
        onPanEnd: (_) => _snapToNearestCorner(size),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PipContent(call: widget.call),
              Positioned(
                right: 4,
                top: 4,
                child: _PipEndCallButton(
                  onTap: () =>
                      ref.read(activeCallControllerProvider.notifier).hangUp(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipContent extends ConsumerWidget {
  final ActiveCallUiState call;

  const _PipContent({required this.call});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peer = ref.watch(publicProfileProvider(call.otherUid!)).valueOrNull;
    final showVideo =
        call.isVideo && call.hasRemoteVideo && call.remoteRenderer != null;

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo)
            RTCVideoView(
              call.remoteRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF2A2A2A),
                backgroundImage: peer?.photoUrl != null
                    ? NetworkImage(peer!.photoUrl!)
                    : null,
                child: peer?.photoUrl == null
                    ? Text(
                        (peer?.name.isNotEmpty ?? false)
                            ? peer!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Text(
              call.status == CallStatus.accepted
                  ? _formatDuration(call.duration)
                  : '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipEndCallButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PipEndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}
