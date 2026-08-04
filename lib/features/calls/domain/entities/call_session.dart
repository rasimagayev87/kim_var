enum CallType { audio, video }

enum CallStatus { ringing, accepted, declined, ended }

/// One call between two users. Mirrors the flow described for the chat
/// call buttons: caller starts it, the receiver sees `ringing` and can
/// accept/decline, either side can end an active call.
///
/// Not wired to any transport yet — see [CallRepository] for why.
class CallSession {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType type;
  final CallStatus status;
  final DateTime startedAt;

  const CallSession({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.startedAt,
  });
}
