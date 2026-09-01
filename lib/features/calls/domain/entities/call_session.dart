enum CallType { audio, video }

/// `busy` is written by `onCallCreated` (Cloud Function) when the
/// callee is already in another `accepted` call. It never rings — the
/// caller sees "Məşğuldur" and the call ends immediately, which also
/// runs the caller's normal end-of-call path so a "missed call" chat
/// message is still logged for the callee to find later.
enum CallStatus { ringing, accepted, declined, ended, busy }

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

  /// Set by the CALLEE's device the moment it actually shows the
  /// incoming-call UI — written nowhere else (`firestore.rules`
  /// restricts it to `receiverId`).
  ///
  /// This is what separates "Zəng gedir" from "Zəng çalınır" on the
  /// caller's screen. Without it the caller sees the same text whether
  /// the other phone is ringing or switched off, and has no way to
  /// tell waiting from wasting time.
  final DateTime? deliveredAt;

  const CallSession({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.startedAt,
    this.deliveredAt,
  });
}
