/// Thrown by [AccountRepository.deleteAccount] when the current sign-in
/// is too old for Firebase to allow account deletion. The UI catches
/// this specifically and offers [AccountRepository.sendReauthCode] /
/// [confirmReauthCode] — a phone-OTP re-verification step scoped to
/// *this* signed-in user (via `reauthenticateWithCredential`, not a
/// fresh sign-in) — before retrying the delete. Deliberately its own
/// small flow rather than reusing the app's onboarding/login OTP
/// screens, which assume "nobody is signed in yet" and would otherwise
/// need to be taught a "this is actually a reauth, don't touch
/// onboarding state" mode.
class ReauthenticationRequiredException implements Exception {
  const ReauthenticationRequiredException();
}

/// Sensitive, one-shot account actions — kept separate from
/// [PrivacySettingsRepository] since these aren't settings toggles,
/// they're irreversible or data-producing actions with their own
/// re-authentication/error semantics.
abstract class AccountRepository {
  /// Deletes the signed-in user's entire account — Firestore doc and
  /// subcollections, chat message placeholders, events, friend
  /// requests, swipes, other users' block-list references, Storage
  /// files, and the Firebase Auth account itself — via a single
  /// server-side Cloud Function call, so a disconnected/backgrounded
  /// client can't leave it half-done. Checks sign-in freshness first
  /// and throws [ReauthenticationRequiredException] without calling
  /// the function at all if it's too old (the function re-checks this
  /// itself server-side too, as defense-in-depth).
  Future<void> deleteAccount();

  /// Gathers the signed-in user's own `users/{uid}` document into a
  /// single JSON string. Scoped to just that document for Phase 3 —
  /// not their messages or events, which involve other people's data
  /// too and would need a very different (server-side) export pipeline
  /// to do safely.
  Future<String> exportUserData();

  /// Starts phone-OTP re-verification for the currently signed-in user
  /// (not a new sign-in) — call this after catching
  /// [ReauthenticationRequiredException].
  Future<void> sendReauthCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onFailed,
  });

  /// Completes the re-verification started by [sendReauthCode]. On
  /// success, the current session is fresh again and [deleteAccount]
  /// can be retried.
  Future<void> confirmReauthCode({
    required String verificationId,
    required String smsCode,
  });

  /// Updates the Firestore-stored `email` field. NOT a Firebase-Auth
  /// email credential with a verification link — this app has no
  /// transactional email service configured to send one through, and
  /// the account's actual sign-in credential is a synthetic address
  /// unrelated to this real, user-facing contact email. This is a
  /// real write, just a plainer one than "send a confirmation link"
  /// implies.
  Future<void> updateEmail(String newEmail);
}
