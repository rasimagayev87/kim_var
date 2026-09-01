import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/call_session.dart';
import '../providers/active_call_controller.dart';

/// Full-screen call UI — covers both the outgoing ("Zəng edilir...")
/// and the already-accepted ("in call") states for [callId], since
/// they're really one continuous screen from the caller's perspective.
/// The callee only ever reaches this screen after already accepting
/// from `IncomingCallScreen`, so it opens straight into the connecting
/// state for them.
///
/// This widget is a thin view over [activeCallControllerProvider] — it
/// owns none of the call's actual state (renderers, timer, mute/camera
/// flags). That's deliberate: minimizing to the PiP bubble (see
/// `CallPipOverlay`) pops *this route*, and popping must not tear the
/// call down, only this particular view of it.
class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String otherUid;
  final CallType type;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.callId,
    required this.otherUid,
    required this.type,
    required this.isCaller,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    ref.read(activeCallControllerProvider.notifier).start(
          callId: widget.callId,
          otherUid: widget.otherUid,
          type: widget.type,
          isCaller: widget.isCaller,
        );
  }

  void _hangUp() {
    if (_leaving) return;
    _leaving = true;
    ref.read(activeCallControllerProvider.notifier).hangUp();
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }

  void _minimize() {
    ref.read(activeCallControllerProvider.notifier).minimize();
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final peer = ref.watch(publicProfileProvider(widget.otherUid)).valueOrNull;
    final call = ref.watch(activeCallControllerProvider);

    // The call ended (either side hung up/declined) or the user chose
    // to minimize — either way this *view* is done; the controller
    // itself already handled (or is handling) the actual cleanup/PiP
    // switch, this just gets CallScreen off the navigator to match.
    ref.listen(activeCallControllerProvider, (previous, next) {
      if (!_leaving && (!next.hasActiveCall || next.minimized)) {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
      }
    });

    final isVideo = widget.type == CallType.video;
    final statusText = switch (call.status) {
      // "Zəng gedir" vs "Zəng çalınır" — the WhatsApp distinction, and
      // it is a real one: until the callee's device confirms it is
      // showing the call (`deliveredAt`), nobody knows whether the
      // other phone is ringing or switched off. Showing "çalınır"
      // regardless tells the caller to keep waiting for something that
      // may never happen.
      CallStatus.ringing => call.delivered ? loc.callStatusRinging : loc.callStatusDialing,
      CallStatus.busy => loc.callStatusBusy,
      CallStatus.accepted => call.duration == Duration.zero ? loc.callStatusConnecting : _formatDuration(call.duration),
      CallStatus.declined => loc.callDeclinedMessage,
      CallStatus.ended => loc.callEndedMessage,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            // Swipe-down-to-minimize, WhatsApp-style — a plain vertical
            // drag anywhere on the call screen's background. The
            // draggable self-preview/control buttons sit on top in the
            // Stack below and get first refusal at any touch inside
            // their own bounds, so this never fights with dragging the
            // self-preview around.
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 200) _minimize();
            },
            child: Stack(
              children: [
                if (isVideo && call.hasRemoteVideo && call.remoteRenderer != null)
                  Positioned.fill(
                    child: RTCVideoView(call.remoteRenderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  )
                else
                  _PeerAvatar(name: peer?.name, photoUrl: peer?.photoUrl),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      if (!(isVideo && call.hasRemoteVideo))
                        Text(
                          peer?.name ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 6),
                      Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _MinimizeButton(onTap: _minimize),
                ),
                if (isVideo && call.renderersReady && !call.cameraOff && call.localRenderer != null)
                  _DraggableSelfPreview(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: RTCVideoView(call.localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CallControlButton(
                        icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        onTap: () => ref.read(activeCallControllerProvider.notifier).toggleMute(),
                      ),
                      const SizedBox(width: 16),
                      _CallControlButton(
                        icon: call.speakerOn ? Icons.volume_up_rounded : Icons.phone_in_talk_rounded,
                        active: call.speakerOn,
                        onTap: () => ref.read(activeCallControllerProvider.notifier).toggleSpeaker(),
                      ),
                      const SizedBox(width: 16),
                      _CallControlButton(icon: Icons.call_end_rounded, color: Colors.redAccent, size: 64, onTap: _hangUp),
                      if (isVideo) ...[
                        const SizedBox(width: 16),
                        _CallControlButton(
                          icon: call.cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          onTap: () => ref.read(activeCallControllerProvider.notifier).toggleCamera(),
                        ),
                        const SizedBox(width: 16),
                        _CallControlButton(
                          icon: Icons.cameraswitch_rounded,
                          onTap: (call.cameraOff || call.switchingCamera)
                              ? null
                              : () => ref.read(activeCallControllerProvider.notifier).switchCamera(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimizeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MinimizeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String? name;
  final String? photoUrl;

  const _PeerAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleAvatar(
        radius: 64,
        backgroundColor: const Color(0xFF2A2A2A),
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null
            ? Text(
                (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
              )
            : null,
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  /// True highlights the button (solid white fill, dark icon) instead of
  /// the default translucent style — used for toggles like the speaker
  /// button so its current on/off state reads at a glance, the same way
  /// a lit-up speaker icon works in every other calling app.
  final bool active;

  const _CallControlButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white24,
    this.size = 56,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: active ? Colors.white : color, shape: BoxShape.circle),
          child: Icon(icon, color: active ? Colors.black87 : Colors.white, size: size * 0.45),
        ),
      ),
    );
  }
}

/// Freely draggable, pinch-zoomable self-preview bubble —
/// WhatsApp/Instagram-style: the caller's own video stays a small
/// movable box, the remote peer's video takes the full screen behind
/// it (see the `Positioned.fill` remote view in [_CallScreenState.build]).
/// Defaults to the top-right corner, then tracks the finger 1:1 (no
/// physics/spring — a call's PiP bubble just needs to go where you put
/// it), clamped so it can never be dragged off-screen at its current
/// size. A second finger pinches it up to 2x its default size and back
/// down again — `GestureDetector`'s scale gesture family reports both
/// the pan delta and the cumulative scale factor from a single
/// recognizer, so one `onScaleUpdate` handles drag-only (scale stays
/// ~1) and pinch-and-drag together without a separate pan recognizer
/// fighting it for the gesture arena.
class _DraggableSelfPreview extends StatefulWidget {
  final Widget child;

  const _DraggableSelfPreview({required this.child});

  @override
  State<_DraggableSelfPreview> createState() => _DraggableSelfPreviewState();
}

class _DraggableSelfPreviewState extends State<_DraggableSelfPreview> {
  static const _width = 100.0;
  static const _height = 140.0;
  static const _margin = 16.0;
  static const _maxScale = 2.0;

  Offset? _topLeft;
  double _scale = 1.0;
  double _scaleAtGestureStart = 1.0;

  @override
  Widget build(BuildContext context) {
    // `MediaQuery.sizeOf` rather than `LayoutBuilder` deliberately —
    // `LayoutBuilder` inserts its own `RenderObject`, which breaks
    // `Positioned`'s direct-child relationship with the ancestor `Stack`
    // ("Incorrect use of ParentDataWidget"). The call screen's `Stack`
    // fills the full (safe-area-padded) screen, so the screen size is
    // an accurate enough bound for clamping this drag.
    final size = MediaQuery.sizeOf(context);
    final boxWidth = _width * _scale;
    final boxHeight = _height * _scale;
    final maxX = (size.width - boxWidth - _margin).clamp(_margin, double.infinity);
    final maxY = (size.height - boxHeight - _margin).clamp(_margin, double.infinity);
    // Defaults to the top-right corner on first layout, exactly where
    // the fixed PiP used to sit — only diverges from there once the
    // user actually drags it.
    _topLeft ??= Offset(size.width - _width - _margin, _margin);
    final clamped = Offset(_topLeft!.dx.clamp(_margin, maxX), _topLeft!.dy.clamp(_margin, maxY));

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
        onScaleStart: (_) => _scaleAtGestureStart = _scale,
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_scaleAtGestureStart * details.scale).clamp(1.0, _maxScale);
            _topLeft = clamped + details.focalPointDelta;
          });
        },
        child: widget.child,
      ),
    );
  }
}
