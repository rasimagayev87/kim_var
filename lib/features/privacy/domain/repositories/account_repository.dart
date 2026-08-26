import '../../../auth/domain/entities/app_user.dart' show LoginProvider;

/// Thrown by [AccountRepository.deleteAccount] when the current sign-in
/// is too old for Firebase to allow account deletion. The UI catches
/// this specifically and offers a re-authentication step — scoped to
/// *this* signed-in user (via `reauthenticateWithCredential`, not a
/// fresh sign-in) — before retrying the delete, via whichever of
/// [reauthenticateWithApple]/[reauthenticateWithGoogle]/
/// [sendReauthEmailLink] matches [currentLoginProvider].
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

  /// Gathers everything the signed-in user directly owns — profile,
  /// posts, reviews, payment history, saved cards (masked fields
  /// only), who they follow/who follows them, and their recent
  /// notifications — into a single JSON string. Deliberately excludes
  /// message threads and anything else that inherently involves OTHER
  /// people's data too; that would need a very different (server-side,
  /// privacy-reviewed) export pipeline to do safely.
  Future<String> exportUserData();

  /// Which provider the signed-in user originally authenticated with —
  /// determines which of the re-authentication methods below the UI
  /// should offer after catching [ReauthenticationRequiredException].
  LoginProvider currentLoginProvider();

  /// Apple: redoes the native Sign in with Apple flow and re-links the
  /// resulting credential to the current session via
  /// `reauthenticateWithCredential`. On success, the session is fresh
  /// again and [deleteAccount] can be retried immediately.
  Future<void> reauthenticateWithApple();

  /// Google: redoes the native Google Sign-In flow and re-links the
  /// resulting credential to the current session via
  /// `reauthenticateWithCredential`. On success, the session is fresh
  /// again and [deleteAccount] can be retried immediately.
  Future<void> reauthenticateWithGoogle();

  /// Email: sends a fresh sign-in link to the current user's own
  /// email — completion happens later, out-of-band, once they tap it
  /// (see `EmailLinkSignInScreen`, which detects it was opened while
  /// already signed in and calls [reauthenticateWithEmailLink] instead
  /// of starting a new sign-in). Listen to [emailReauthCompleted] to
  /// know when that finished.
  Future<void> sendReauthEmailLink();

  /// Completes the flow [sendReauthEmailLink] started, once the user
  /// taps the emailed link.
  Future<void> reauthenticateWithEmailLink(String link);

  /// Fires once after each successful [reauthenticateWithEmailLink] —
  /// lets the (possibly backgrounded) delete-account UI know the user
  /// came back after tapping the link.
  Stream<void> get emailReauthCompleted;

  /// Sends a confirmation link to [newEmail] via Firebase Auth
  /// (`verifyBeforeUpdateEmail`) — the account's real sign-in email
  /// (Google/Apple/email-link all resolve to a real `user.email`, no
  /// synthetic address involved) only actually changes once the user
  /// taps that link, not synchronously here. Checks sign-in freshness
  /// first and throws [ReauthenticationRequiredException] (same
  /// contract as [deleteAccount]) if it's too old. The Firestore
  /// `users/{uid}.email` mirror is deliberately NOT written here — see
  /// [syncEmailFromAuth], which is what actually closes the loop once
  /// the link is clicked, possibly in a later session.
  Future<void> updateEmail(String newEmail);

  /// Best-effort: reloads the current Firebase Auth user and, if its
  /// `.email` has diverged from the stored `users/{uid}.email` (e.g.
  /// the user clicked an [updateEmail] confirmation link since the
  /// last time this ran), writes the real value back to Firestore.
  /// Safe to call on every app launch — a no-op when nothing changed.
  Future<void> syncEmailFromAuth();
}
