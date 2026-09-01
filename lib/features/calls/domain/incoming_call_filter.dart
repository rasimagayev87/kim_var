/// Decides whether a `calls/{id}` document should open a call UI on the
/// callee's device.
///
/// Extracted from `FirebaseCallRepository.watchIncomingCall` because
/// this predicate is where the "answered from the OS call UI, then
/// nothing happened" bug lived, and because it is the one part of the
/// call flow that can be tested without a device, a microphone or an
/// emulator.
///
/// The query itself matches `receiverId == me && status in ['ringing',
/// 'accepted']`; everything Firestore cannot express is decided here.
library;

/// How long after `createdAt` a call may still open a screen.
///
/// A call document that was never cleaned up must not resurrect itself
/// the next morning. Two minutes is longer than any real ring — the
/// caller's own unanswered timeout is shorter — and short enough that a
/// stale document can never surprise anyone.
const Duration kIncomingCallMaxAge = Duration(minutes: 2);

/// True when this document should surface as an incoming/resumable call.
///
/// [hasAnswer] is the discriminator that Firestore cannot filter on (it
/// has no "field is missing" operator). An `accepted` call that already
/// carries an answer is either already connected on this device or was
/// answered on another one, and setting it up a second time would
/// produce two PeerConnections racing to answer the same offer.
bool shouldSurfaceIncomingCall({
  required String? status,
  required bool hasAnswer,
  required DateTime? createdAt,
  required DateTime now,
}) {
  if (status != 'ringing' && status != 'accepted') return false;
  if (status == 'accepted' && hasAnswer) return false;
  if (createdAt != null && now.difference(createdAt) > kIncomingCallMaxAge)
    return false;
  return true;
}
