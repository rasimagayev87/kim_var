import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../domain/entities/call_session.dart';
import '../providers/call_providers.dart';

/// Full-screen call UI — covers both the outgoing ("Zəng edilir...")
/// and the already-accepted ("in call") states for [callId], since
/// they're really one continuous screen from the caller's perspective.
/// The callee only ever reaches this screen after already accepting
/// from `IncomingCallScreen`, so it opens straight into the connecting
/// state for them.
class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String otherUid;
  final CallType type;

  const CallScreen({super.key, required this.callId, required this.otherUid, required this.type});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  bool _renderersReady = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _hasRemoteVideo = false;
  bool _switchingCamera = false;
  // Video calls default to loudspeaker (holding the phone up to your ear
  // through a video call isn't practical); voice calls default to the
  // earpiece, matching every other calling app's convention.
  late bool _speakerOn = _isVideo;
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _leaving = false;
  // Only ever heard on this screen while `status == ringing`, which per
  // this class's own doc comment only ever happens for the caller (the
  // callee reaches this screen already past `acceptCall`) — so this is
  // the outgoing ringback, not an incoming ringtone.
  final _ringbackPlayer = AudioPlayer();
  bool _ringbackPlaying = false;

  bool get _isVideo => widget.type == CallType.video;

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initRenderers();
    ref.read(callRepositoryProvider).setSpeakerphoneOn(widget.callId, _speakerOn);
  }

  Future<void> _initRenderers() async {
    final local = RTCVideoRenderer();
    final remote = RTCVideoRenderer();
    await local.initialize();
    await remote.initialize();
    if (!mounted) {
      await local.dispose();
      await remote.dispose();
      return;
    }
    setState(() {
      _localRenderer = local;
      _remoteRenderer = remote;
      _renderersReady = true;
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _ringbackPlayer.dispose();
    super.dispose();
  }

  Future<void> _updateRingback(CallStatus status) async {
    final shouldPlay = status == CallStatus.ringing;
    if (shouldPlay == _ringbackPlaying) return;
    _ringbackPlaying = shouldPlay;
    if (shouldPlay) {
      await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringbackPlayer.play(AssetSource('sounds/ringback.wav'));
    } else {
      await _ringbackPlayer.stop();
    }
  }

  void _startDurationTimerOnce() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    await ref.read(callRepositoryProvider).endCall(widget.callId);
    navigator.pop();
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
    final session = ref.watch(callSessionProvider(widget.callId)).valueOrNull;

    ref.listen(callSessionProvider(widget.callId), (previous, next) {
      final status = next.valueOrNull?.status;
      if (status == CallStatus.accepted) _startDurationTimerOnce();
      if (status == CallStatus.declined || status == CallStatus.ended) _leave();
    });

    if (_isVideo && _renderersReady) {
      ref.listen(localCallStreamProvider(widget.callId), (previous, next) {
        _localRenderer?.srcObject = next.valueOrNull;
      });
      ref.listen(remoteCallStreamProvider(widget.callId), (previous, next) {
        _remoteRenderer?.srcObject = next.valueOrNull;
        if (next.valueOrNull != null && mounted) setState(() => _hasRemoteVideo = true);
      });
    }

    final status = session?.status ?? CallStatus.ringing;
    _updateRingback(status);
    final statusText = switch (status) {
      CallStatus.ringing => loc.callStatusRinging,
      CallStatus.accepted => _duration == Duration.zero ? loc.callStatusConnecting : _formatDuration(_duration),
      CallStatus.declined => loc.callDeclinedMessage,
      CallStatus.ended => loc.callEndedMessage,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isVideo && _hasRemoteVideo && _remoteRenderer != null)
                Positioned.fill(child: RTCVideoView(_remoteRenderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
              else
                _PeerAvatar(name: peer?.name, photoUrl: peer?.photoUrl),
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    if (!(_isVideo && _hasRemoteVideo))
                      Text(
                        peer?.name ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 6),
                    Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
              if (_isVideo && _renderersReady && !_cameraOff && _localRenderer != null)
                _DraggableSelfPreview(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: RTCVideoView(_localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
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
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      onTap: () {
                        setState(() => _muted = !_muted);
                        ref.read(callRepositoryProvider).setMuted(widget.callId, _muted);
                      },
                    ),
                    const SizedBox(width: 16),
                    _CallControlButton(
                      icon: _speakerOn ? Icons.volume_up_rounded : Icons.phone_in_talk_rounded,
                      active: _speakerOn,
                      onTap: () {
                        setState(() => _speakerOn = !_speakerOn);
                        ref.read(callRepositoryProvider).setSpeakerphoneOn(widget.callId, _speakerOn);
                      },
                    ),
                    const SizedBox(width: 16),
                    _CallControlButton(icon: Icons.call_end_rounded, color: Colors.redAccent, size: 64, onTap: _leave),
                    if (_isVideo) ...[
                      const SizedBox(width: 16),
                      _CallControlButton(
                        icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        onTap: () {
                          setState(() => _cameraOff = !_cameraOff);
                          ref.read(callRepositoryProvider).setVideoEnabled(widget.callId, !_cameraOff);
                        },
                      ),
                      const SizedBox(width: 16),
                      _CallControlButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: (_cameraOff || _switchingCamera)
                            ? null
                            : () async {
                                setState(() => _switchingCamera = true);
                                await ref.read(callRepositoryProvider).switchCamera(widget.callId);
                                if (mounted) setState(() => _switchingCamera = false);
                              },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

/// Freely draggable self-preview bubble — WhatsApp/Instagram-style: the
/// caller's own video stays a small movable box, the remote peer's video
/// takes the full screen behind it (see the `Positioned.fill` remote
/// view in [_CallScreenState.build]). Defaults to the top-right corner,
/// then tracks the finger 1:1 (no physics/spring — a call's PiP bubble
/// just needs to go where you put it), clamped so it can never be
/// dragged fully off-screen.
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

  Offset? _topLeft;

  @override
  Widget build(BuildContext context) {
    // `MediaQuery.sizeOf` rather than `LayoutBuilder` deliberately —
    // `LayoutBuilder` inserts its own `RenderObject`, which breaks
    // `Positioned`'s direct-child relationship with the ancestor `Stack`
    // ("Incorrect use of ParentDataWidget"). The call screen's `Stack`
    // fills the full (safe-area-padded) screen, so the screen size is
    // an accurate enough bound for clamping this drag.
    final size = MediaQuery.sizeOf(context);
    final maxX = size.width - _width - _margin;
    final maxY = size.height - _height - _margin;
    // Defaults to the top-right corner on first layout, exactly where
    // the fixed PiP used to sit — only diverges from there once the
    // user actually drags it.
    _topLeft ??= Offset(maxX, _margin);
    final clamped = Offset(_topLeft!.dx.clamp(_margin, maxX), _topLeft!.dy.clamp(_margin, maxY));

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      width: _width,
      height: _height,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() => _topLeft = clamped + details.delta),
        child: widget.child,
      ),
    );
  }
}
