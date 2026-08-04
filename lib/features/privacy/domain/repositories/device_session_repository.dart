import '../entities/device_session.dart';

/// See the "IMPORTANT" doc comment on [DeviceSession] — signing out
/// *other* devices for real needs a Cloud Function; this interface only
/// promises what a Flutter client can actually deliver on its own.
abstract class DeviceSessionRepository {
  Stream<List<DeviceSession>> watchSessions(String uid);

  /// Called on sign-in / app resume so the current device has an
  /// up-to-date session doc for [watchSessions] to show.
  Future<void> touchCurrentSession(String uid);

  /// Removes a session's Firestore doc — a *soft* sign-out (see
  /// [DeviceSession] doc comment for why this alone doesn't force that
  /// device offline).
  Future<void> removeSession(String uid, String sessionId);

  /// This device's own session id — lets [SessionGuard] watch its own
  /// doc and sign itself out locally if another device removes it
  /// (the *hard* half of the revoke, see [DeviceSession]'s doc comment).
  Future<String> currentSessionId();
}
