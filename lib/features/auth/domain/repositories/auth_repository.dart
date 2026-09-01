import '../entities/app_user.dart';

/// Thrown by [AuthRepository.completeOnboarding] when the server-side
/// minimum-age check (`completeOnboarding` Cloud Function, 18+) rejects
/// the submitted birth date. The date-picker bound in
/// `OnboardingScreen`/`EditProfileScreen` is UX only — this exception is
/// what the UI catches to show a specific, localized message rather than
/// the generic error fallback.
class UnderageOnboardingException implements Exception {
  const UnderageOnboardingException();
}

/// Thrown by [AuthRepository.completeOnboarding] when the caller signed
/// up with email+password and hasn't clicked the verification link yet
/// — `completeOnboarding` (Cloud Function) checks
/// `request.auth.token.email_verified` server-side (Google/Apple are
/// exempt, their email is already provider-verified). In the normal
/// flow the client never even reaches `completeOnboarding` in this
/// state ([VerifyEmailScreen] sits in front of it) — this exception is
/// the defense-in-depth path for a modified/stale client that skips
/// straight there.
class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();
}

/// Abstraction over the authentication backend (Firebase Auth).
///
/// Sign-in is exactly 3 methods — Apple, Google, or email+password.
/// (Phone/OTP was fully removed in an earlier pass, see
/// `7d6f0bb`/`26fa8cf`; passwordless email-link was replaced by
/// email+password because the Identity Toolkit project config already
/// requires a password for the email provider — `signIn.email.
/// passwordRequired: true` — and a real password is faster/more
/// familiar than "go check your inbox for a link" anyway.) Each
/// sign-in method returns whether the account is brand new (caller
/// should route to [AuthRepository.completeOnboarding]) or already
/// exists. A separate public `@username` handle is still collected
/// during onboarding (see [isUsernameAvailable]) —
/// purely a display name, never itself a sign-in credential.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Restores a previously signed-in Firebase session. Returns null
  /// if there's no session, or if there IS a session but the user
  /// never finished onboarding — check [needsOnboarding] in that case.
  Future<AppUser?> restoreSession();

  /// True if a Firebase session exists but no Firestore user
  /// document has been created yet (onboarding was never completed).
  bool get needsOnboarding;

  /// True if [username] isn't yet reserved. Backs the onboarding
  /// form's debounced availability check — not a hard guarantee
  /// against a same-instant race, [completeOnboarding] itself (via
  /// the `usernames/{username}` create-fails-if-exists rule) is the
  /// actual source of truth.
  Future<bool> isUsernameAvailable(String username);

  /// Signs in with "Sign in with Apple". Apple only ever supplies a
  /// real name on the FIRST authorization for a given app+account
  /// pair — never relied on here, the onboarding form always asks for
  /// first/last name itself regardless of provider.
  Future<(AppUser user, bool isNewUser)> signInWithApple();

  /// Signs in with Google (native `GoogleSignIn` account picker).
  Future<(AppUser user, bool isNewUser)> signInWithGoogle();

  /// Signs in an EXISTING email+password account.
  /// `firebase_auth: FirebaseAuthException` codes (`wrong-password`,
  /// `user-not-found`, `invalid-credential`) are deliberately not
  /// distinguished by the caller's error copy — showing one generic
  /// "email or password is wrong" message either way avoids leaking
  /// which part was incorrect (account-enumeration hygiene).
  Future<(AppUser user, bool isNewUser)> signInWithEmailPassword(
    String email,
    String password,
  );

  /// Creates a brand-new email+password account. Always the
  /// `isNewUser: true` case in practice, but routed through the same
  /// `_afterSignIn`/doc-existence check every other provider uses,
  /// rather than assumed, to stay consistent.
  Future<(AppUser user, bool isNewUser)> registerWithEmailPassword(
    String email,
    String password,
  );

  /// Sends a Firebase password-reset email to [email]. Silently
  /// succeeds even for an email with no account — Firebase's own
  /// `sendPasswordResetEmail` behaves this way already, which is the
  /// correct account-enumeration-safe default, so the caller shouldn't
  /// try to detect/report "no such account" here either.
  Future<void> sendPasswordResetEmail(String email);

  /// Re-sends the verification link to the CURRENTLY signed-in user's
  /// own email — [VerifyEmailScreen]'s "Yenidən göndər" button. Throws
  /// if nobody's signed in; that shouldn't be reachable from that
  /// screen in practice.
  Future<void> resendEmailVerification();

  /// Re-fetches the current Firebase user's own record (Firebase Auth
  /// caches `emailVerified` locally and only learns it changed via an
  /// explicit reload) and returns whether it's now verified —
  /// [VerifyEmailScreen]'s "Davam et" button.
  Future<bool> reloadAndCheckEmailVerified();

  /// Called once, right after first sign-in, to create the Firestore
  /// user document with the onboarding data — including reserving
  /// [username], the first time this account gets one (no earlier
  /// registration step sets it the way the old username+password flow
  /// did, since Apple/Google/E-mail sign-in has no concept of it).
  Future<AppUser> completeOnboarding({
    required String username,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    required String phoneNumber,
    required String businessStatus,
    String? bio,
  });

  Future<void> signOut();

  // `updateUsername` was REMOVED here. Renaming a handle now goes
  // through the `updateProfileDetails` Cloud Function
  // (`ProfileController.save`), because `users.username` is locked in
  // `firestore.rules` and the once-per-30-days cooldown has to live
  // somewhere a client cannot rewrite. A client-side implementation
  // could no longer succeed at all.
}
