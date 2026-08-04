/// One signed-in device, tracked in a `users/{uid}/sessions/{sessionId}`
/// subcollection that each device writes/refreshes for itself on
/// sign-in and app resume.
///
/// IMPORTANT — read before wiring up Phase 2: the Firebase Auth client
/// SDK has no API to list or revoke a user's other active sessions;
/// that's an Admin SDK / Cloud Functions capability (`admin.auth()
/// .revokeRefreshTokens(uid)`), not something a Flutter client can do
/// directly. This entity/repository model a *soft* session list — the
/// app can show "signed in on: ..." and delete a session's Firestore
/// doc — but deleting the doc alone does not force that other device to
/// actually sign out; it would need a Cloud Function (or that other
/// client periodically checking its own session doc still exists and
/// signing itself out if not) to be a *hard* revoke. Flagged for
/// discussion when we get to Phase 2, same as the calling feature's
/// WebRTC gap.
class DeviceSession {
  final String id;
  final String deviceName;
  final String platform;
  final DateTime lastActiveAt;
  final bool isCurrentDevice;

  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.lastActiveAt,
    required this.isCurrentDevice,
  });
}
