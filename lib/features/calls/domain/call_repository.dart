import 'package:webrtc_interface/webrtc_interface.dart' show MediaStream;

import 'entities/call_session.dart';

/// Seam for the WebRTC-backed calling feature. `FirebaseCallRepository`
/// is the real implementation (Firestore for signaling, Cloudflare
/// Realtime for TURN); each instance holds the live `RTCPeerConnection`
/// for whatever call is currently active, so [watchLocalStream] /
/// [watchRemoteStream] only ever have one call's media to report on at
/// a time — matches the app's one-call-at-a-time UI.
abstract class CallRepository {
  /// Starts a call to [receiverId] and returns the created session.
  Future<CallSession> startCall({required String receiverId, required CallType type});

  /// Live incoming-call notifications for the current user — a caller
  /// starting a call against this user's uid should appear here as a
  /// `CallStatus.ringing` session.
  Stream<CallSession?> watchIncomingCall();

  /// Live updates for a specific in-progress call, so both sides observe
  /// accept/decline/end without polling.
  Stream<CallSession?> watchCall(String callId);

  Future<void> acceptCall(String callId);

  Future<void> declineCall(String callId);

  Future<void> endCall(String callId);

  /// This device's own camera/mic feed for [callId] — null until the
  /// local `getUserMedia()` call resolves, which happens as soon as
  /// [startCall] or [acceptCall] is invoked (not before — no reason to
  /// touch the camera/mic just because the call screen is open).
  Stream<MediaStream?> watchLocalStream(String callId);

  /// The other participant's audio/video feed for [callId] — null until
  /// the peer connection's first remote track arrives, which only
  /// happens after both sides have exchanged SDP (i.e. some time after
  /// [acceptCall]).
  Stream<MediaStream?> watchRemoteStream(String callId);

  /// Mutes/unmutes this device's own outgoing audio track. No Firestore
  /// write involved — the other side simply stops receiving audio
  /// frames, same as any WebRTC call.
  Future<void> setMuted(String callId, bool muted);

  /// Enables/disables this device's own outgoing video track. A no-op
  /// on an audio-only call (there's no video track to toggle).
  Future<void> setVideoEnabled(String callId, bool enabled);

  /// Flips this device's own outgoing video between front and back
  /// camera. A no-op on an audio-only call or once the video track has
  /// been disabled (nothing to switch).
  Future<void> switchCamera(String callId);

  /// Routes this call's audio through the loudspeaker (`true`) or the
  /// earpiece/default output (`false`). No Firestore write — purely a
  /// local device setting, same as [setMuted].
  Future<void> setSpeakerphoneOn(String callId, bool enabled);
}
