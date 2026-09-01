import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/call_session.dart';
import 'call_providers.dart';

/// Everything about the *currently active* call that used to live as
/// local `State` on `_CallScreenState` — renderers, mute/camera/speaker
/// flags, the duration timer, the ringback player. Pulling all of it
/// out into a provider that outlives any particular route is what
/// makes minimize-to-PiP possible at all: popping `CallScreen` off the
/// navigator no longer tears any of this down, since none of it
/// belongs to `CallScreen` anymore. `CallScreen` and `CallPipOverlay`
/// are just two different views onto this same state.
class ActiveCallUiState {
  final String? callId;
  final String? otherUid;
  final CallType? type;
  final bool isCaller;
  final bool minimized;

  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;
  final bool renderersReady;
  final bool hasRemoteVideo;

  /// The callee's device has confirmed it is showing the incoming-call
  /// UI (`calls/{id}.deliveredAt`). Only meaningful while `ringing`,
  /// and only to the caller — it is what turns "Zəng gedir" into
  /// "Zəng çalınır".
  final bool delivered;

  final bool muted;
  final bool cameraOff;
  final bool speakerOn;
  final bool switchingCamera;

  final CallStatus status;
  final bool everAccepted;
  final Duration duration;

  const ActiveCallUiState({
    this.callId,
    this.otherUid,
    this.type,
    this.isCaller = false,
    this.minimized = false,
    this.localRenderer,
    this.remoteRenderer,
    this.renderersReady = false,
    this.hasRemoteVideo = false,
    this.delivered = false,
    this.muted = false,
    this.cameraOff = false,
    this.speakerOn = false,
    this.switchingCamera = false,
    this.status = CallStatus.ringing,
    this.everAccepted = false,
    this.duration = Duration.zero,
  });

  bool get hasActiveCall => callId != null;
  bool get isVideo => type == CallType.video;

  ActiveCallUiState copyWith({
    String? callId,
    String? otherUid,
    CallType? type,
    bool? isCaller,
    bool? minimized,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
    bool? renderersReady,
    bool? hasRemoteVideo,
    bool? delivered,
    bool? muted,
    bool? cameraOff,
    bool? speakerOn,
    bool? switchingCamera,
    CallStatus? status,
    bool? everAccepted,
    Duration? duration,
  }) {
    return ActiveCallUiState(
      callId: callId ?? this.callId,
      otherUid: otherUid ?? this.otherUid,
      type: type ?? this.type,
      isCaller: isCaller ?? this.isCaller,
      minimized: minimized ?? this.minimized,
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderer: remoteRenderer ?? this.remoteRenderer,
      renderersReady: renderersReady ?? this.renderersReady,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      delivered: delivered ?? this.delivered,
      muted: muted ?? this.muted,
      cameraOff: cameraOff ?? this.cameraOff,
      speakerOn: speakerOn ?? this.speakerOn,
      switchingCamera: switchingCamera ?? this.switchingCamera,
      status: status ?? this.status,
      everAccepted: everAccepted ?? this.everAccepted,
      duration: duration ?? this.duration,
    );
  }
}

class ActiveCallController extends StateNotifier<ActiveCallUiState> {
  ActiveCallController(this._ref) : super(const ActiveCallUiState());

  final Ref _ref;

  StreamSubscription<CallSession?>? _sessionSub;
  StreamSubscription<MediaStream?>? _localStreamSub;
  StreamSubscription<MediaStream?>? _remoteStreamSub;
  Timer? _durationTimer;
  final _ringbackPlayer = AudioPlayer();
  bool _ringbackPlaying = false;
  bool _ending = false;

  /// Called once, when a call screen is first reached — either just
  /// after `startCall` (caller) or just after `acceptCall` (callee).
  /// Safe to call again for the same [callId] (e.g. `CallScreen`
  /// re-attaching after a restore-from-PiP) — it's a no-op then.
  Future<void> start({required String callId, required String otherUid, required CallType type, required bool isCaller}) async {
    if (state.callId == callId) return;
    await _teardown();
    _ending = false;

    state = ActiveCallUiState(
      callId: callId,
      otherUid: otherUid,
      type: type,
      isCaller: isCaller,
      speakerOn: type == CallType.video,
    );

    final repo = _ref.read(callRepositoryProvider);
    unawaited(repo.setSpeakerphoneOn(callId, state.speakerOn));

    if (type == CallType.video) {
      unawaited(_initRenderers());
    }

    _sessionSub = _ref.read(callRepositoryProvider).watchCall(callId).listen(_onSessionUpdate);
    // `watchLocalStream`/`watchRemoteStream` already replay whatever
    // stream is currently open to a *new* subscriber (see that
    // method's own doc comment in firebase_call_repository.dart) — but
    // that only solves subscribing late relative to when the stream
    // opened. It doesn't solve subscribing *before the renderer
    // exists*: `startCall`/`acceptCall` opens the local camera before
    // this controller ever runs, so this listener's first (and often
    // only, for a stream that doesn't change again) event can easily
    // fire while `_initRenderers` is still mid-`await` and
    // `state.localRenderer` is still null — `?.srcObject = stream`
    // then silently no-ops, and nothing re-applies it once the
    // renderer shows up. Tracking the last-seen stream here and
    // re-applying it once the renderer exists (in `_initRenderers`)
    // closes that race regardless of which finishes first.
    _localStreamSub = repo.watchLocalStream(callId).listen((stream) {
      _lastLocalStream = stream;
      state.localRenderer?.srcObject = stream;
    });
    _remoteStreamSub = repo.watchRemoteStream(callId).listen((stream) {
      _lastRemoteStream = stream;
      state.remoteRenderer?.srcObject = stream;
      if (stream != null) state = state.copyWith(hasRemoteVideo: true);
    });
  }

  MediaStream? _lastLocalStream;
  MediaStream? _lastRemoteStream;

  Future<void> _initRenderers() async {
    final local = RTCVideoRenderer();
    final remote = RTCVideoRenderer();
    await local.initialize();
    await remote.initialize();
    if (!mounted || state.callId == null) {
      await local.dispose();
      await remote.dispose();
      return;
    }
    local.srcObject = _lastLocalStream;
    remote.srcObject = _lastRemoteStream;
    state = state.copyWith(
      localRenderer: local,
      remoteRenderer: remote,
      renderersReady: true,
      hasRemoteVideo: _lastRemoteStream != null,
    );
  }

  void _onSessionUpdate(CallSession? session) {
    if (session == null || !mounted) return;
    if (session.status == CallStatus.accepted && !state.everAccepted) {
      state = state.copyWith(status: session.status, everAccepted: true);
      _startDurationTimerOnce();
    } else {
      state = state.copyWith(status: session.status);
    }
    // Latches: once the phone has rung, a later snapshot without the
    // field must not walk the caller's text back to "Zəng gedir".
    if (session.deliveredAt != null && !state.delivered) {
      state = state.copyWith(delivered: true);
    }
    _updateRingback(session.status);
    // `busy` ends the call the same way a decline does — and
    // deliberately goes through the SAME path, because that path is
    // what logs the "missed call" chat message. The callee never saw
    // the call, so the record is the only way they learn it happened.
    if (session.status == CallStatus.declined ||
        session.status == CallStatus.ended ||
        session.status == CallStatus.busy) {
      unawaited(_finish());
    }
  }

  Future<void> _updateRingback(CallStatus status) async {
    // Only the caller ever hears this — the callee reaches this
    // controller already past `acceptCall`, so `status` never reads
    // `ringing` on their side.
    final shouldPlay = status == CallStatus.ringing && state.isCaller;
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
      if (mounted) state = state.copyWith(duration: state.duration + const Duration(seconds: 1));
    });
  }

  void minimize() {
    if (state.hasActiveCall) state = state.copyWith(minimized: true);
  }

  void restore() {
    if (state.hasActiveCall) state = state.copyWith(minimized: false);
  }

  void toggleMute() {
    final next = !state.muted;
    state = state.copyWith(muted: next);
    if (state.callId != null) _ref.read(callRepositoryProvider).setMuted(state.callId!, next);
  }

  void toggleSpeaker() {
    final next = !state.speakerOn;
    state = state.copyWith(speakerOn: next);
    if (state.callId != null) _ref.read(callRepositoryProvider).setSpeakerphoneOn(state.callId!, next);
  }

  void toggleCamera() {
    final next = !state.cameraOff;
    state = state.copyWith(cameraOff: next);
    if (state.callId != null) _ref.read(callRepositoryProvider).setVideoEnabled(state.callId!, !next);
  }

  Future<void> switchCamera() async {
    if (state.cameraOff || state.switchingCamera || state.callId == null) return;
    state = state.copyWith(switchingCamera: true);
    await _ref.read(callRepositoryProvider).switchCamera(state.callId!);
    if (mounted) state = state.copyWith(switchingCamera: false);
  }

  /// User-initiated hang-up (either side). The other side's own
  /// controller instance observes the resulting `ended` status via its
  /// own `_onSessionUpdate` and finishes on its own — this only needs
  /// to write the Firestore status change, not coordinate directly with
  /// the peer.
  Future<void> hangUp() async {
    if (state.callId == null) return;
    await _ref.read(callRepositoryProvider).endCall(state.callId!);
    await _finish();
  }

  /// Common cleanup path for every way a call can end: this device
  /// hanging up, the other side hanging up/declining, or a call that
  /// was never answered. Idempotent — safe to call more than once (both
  /// the direct hang-up path and the session-status listener can reach
  /// this for the same call).
  Future<void> _finish() async {
    if (_ending || state.callId == null) return;
    _ending = true;

    final callId = state.callId!;
    final otherUid = state.otherUid!;
    final type = state.type!;
    final isCaller = state.isCaller;
    final everAccepted = state.everAccepted;
    final duration = state.duration;

    // Read stats before the repository tears the peer connection down
    // — `endCall` (already called by `hangUp`, or about to run below
    // for the "other side ended it" path) closes the connection
    // `getStats()` would otherwise read from.
    final dataUsage = everAccepted ? await _ref.read(callRepositoryProvider).getDataUsageBytes(callId) : null;
    // Covers the "other side ended it" / "declined" paths, where
    // nothing has called `endCall` yet. A no-op (repository-level) if
    // this device already called it via `hangUp`.
    unawaited(_ref.read(callRepositoryProvider).endCall(callId).catchError((_) {}));

    // Only the caller logs the call — see the doc comment on
    // `ChatRepository.logCallMessage`. The callee's own controller
    // instance reaches this same method but skips the write.
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (isCaller && myUid != null) {
      unawaited(
        _ref.read(chatControllerProvider.notifier).logCall(
              otherUid: otherUid,
              callId: callId,
              callerId: myUid,
              callMessageType: type == CallType.video ? CallMessageType.video : CallMessageType.voice,
              callOutcome: everAccepted ? CallMessageOutcome.completed : CallMessageOutcome.missed,
              callDurationSeconds: everAccepted ? duration.inSeconds : null,
              callDataUsageBytes: dataUsage,
            ),
      );
    }

    await _teardown();
    state = const ActiveCallUiState();
  }

  Future<void> _teardown() async {
    await _sessionSub?.cancel();
    await _localStreamSub?.cancel();
    await _remoteStreamSub?.cancel();
    _sessionSub = null;
    _localStreamSub = null;
    _remoteStreamSub = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    await state.localRenderer?.dispose();
    await state.remoteRenderer?.dispose();
    await _ringbackPlayer.stop();
    _ringbackPlaying = false;
  }

  @override
  void dispose() {
    _teardown();
    _ringbackPlayer.dispose();
    super.dispose();
  }
}

/// Not `.autoDispose` — this must survive `CallScreen` (and everything
/// else) being popped off the navigator, which is the entire point.
final activeCallControllerProvider = StateNotifierProvider<ActiveCallController, ActiveCallUiState>((ref) {
  return ActiveCallController(ref);
});
