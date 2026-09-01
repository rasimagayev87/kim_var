import 'package:webrtc_interface/webrtc_interface.dart' show MediaStream;

import '../domain/call_repository.dart';
import '../domain/entities/call_session.dart';

/// Placeholder [CallRepository] wired into the app today so the AppBar
/// call buttons have a real (if inert) service layer behind them instead
/// of a fake ringing screen. Every method either throws or reports "no
/// call" — the UI is expected to catch that and show the coming-soon
/// notice rather than call these directly in a hot path.
///
/// What's actually needed before a real implementation can replace this:
///
/// 1. A WebRTC client — `flutter_webrtc` (the standard Flutter binding
///    for Google's WebRTC), added as a new pubspec dependency.
/// 2. Signaling (exchanging SDP offer/answer + ICE candidates between
///    the two peers). No separate server is strictly required for this
///    part — a `calls/{callId}` Firestore document with the existing
///    real-time listeners this app already uses for chat can carry the
///    offer/answer/candidates, mirroring the `chats` collection's
///    pattern. `firestore.rules` would need a matching `calls` section
///    (participants-only read/write, same shape as the `chats` rule).
/// 3. A TURN server for relaying media when both devices are behind
///    NATs that can't connect directly (common on mobile networks) — a
///    STUN-only setup will work on the same Wi-Fi but fail across most
///    real-world mobile connections. This is infrastructure the app
///    doesn't have today: either a managed TURN provider (Twilio,
///    Xirsys, Cloudflare Calls) or a self-hosted `coturn` instance.
/// 4. Foreground-service/CallKit-style platform wiring so an incoming
///    call can wake the app (or show a native call UI) when it isn't in
///    the foreground — `flutter_callkit_incoming` or similar.
///
/// None of that is added here — it's a real infrastructure/cost decision
/// (#3 especially) that should be made explicitly, not implied by a
/// dependency bump.
class UnimplementedCallRepository implements CallRepository {
  const UnimplementedCallRepository();

  @override
  Future<CallSession> startCall({
    required String receiverId,
    required CallType type,
  }) {
    throw UnimplementedError(
      'Calling requires a WebRTC + signaling backend — see class doc comment.',
    );
  }

  @override
  Stream<CallSession?> watchIncomingCall() => Stream.value(null);

  @override
  Stream<CallSession?> watchCall(String callId) => Stream.value(null);

  @override
  Future<void> acceptCall(String callId) => throw UnimplementedError();

  @override
  Future<void> declineCall(String callId) => throw UnimplementedError();

  @override
  Future<void> endCall(String callId) => throw UnimplementedError();

  @override
  Stream<MediaStream?> watchLocalStream(String callId) => Stream.value(null);

  @override
  Stream<MediaStream?> watchRemoteStream(String callId) => Stream.value(null);

  @override
  Future<void> setMuted(String callId, bool muted) =>
      throw UnimplementedError();

  @override
  Future<void> setVideoEnabled(String callId, bool enabled) =>
      throw UnimplementedError();

  @override
  Future<void> switchCamera(String callId) => throw UnimplementedError();

  @override
  Future<void> setSpeakerphoneOn(String callId, bool enabled) =>
      throw UnimplementedError();

  @override
  Future<int?> getDataUsageBytes(String callId) => Future.value(null);
}
