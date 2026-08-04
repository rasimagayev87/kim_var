import 'dart:async';

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
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _leaving = false;

  bool get _isVideo => widget.type == CallType.video;

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initRenderers();
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
    super.dispose();
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
                Positioned(
                  top: 24,
                  right: 16,
                  width: 100,
                  height: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RTCVideoView(_localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
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
                    const SizedBox(width: 20),
                    _CallControlButton(icon: Icons.call_end_rounded, color: Colors.redAccent, size: 64, onTap: _leave),
                    if (_isVideo) ...[
                      const SizedBox(width: 20),
                      _CallControlButton(
                        icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        onTap: () {
                          setState(() => _cameraOff = !_cameraOff);
                          ref.read(callRepositoryProvider).setVideoEnabled(widget.callId, !_cameraOff);
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
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _CallControlButton({required this.icon, required this.onTap, this.color = Colors.white24, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
