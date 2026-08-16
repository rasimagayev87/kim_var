import '../entities/app_user.dart';

/// Abstraction over the authentication backend (Firebase Auth).
///
/// Sign-in is username + password. There's no native "username"
/// provider in Firebase Auth, so under the hood each account signs in
/// with a random, never-shown synthetic email — see
/// `FirebaseAuthRepository._randomAuthEmail` — resolved from the
/// chosen username via the `usernames` Firestore collection, which is
/// also what lets [updateUsername] rename the handle without ever
/// touching the sign-in credential. Phone number is not a sign-in
/// method at all; it's a per-account verification/recovery factor
/// (account verification, forgot password).
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

  /// True if [username] isn't yet reserved. Backs the register
  /// screen's debounced availability check — not a hard guarantee
  /// against a same-instant race, [registerWithUsername] is the
  /// actual source of truth (Firebase Auth's own email uniqueness).
  Future<bool> isUsernameAvailable(String username);

  /// Creates the Firebase Auth user and reserves [username]. Signs
  /// the caller out immediately after — registration never leaves you
  /// signed in, the UI always routes to Login next.
  ///
  /// [termsAccepted]/[termsVersion]/[privacyVersion] record the legal
  /// consent the registration screen's checkbox gates on — written
  /// onto the `usernames/{username}` reservation doc (the only thing
  /// created at this point; `users/{uid}` itself doesn't exist until
  /// `completeOnboarding`, which is a genuinely separate session after
  /// the forced sign-out above) and copied onto `users/{uid}.consent`
  /// once that doc is created.
  Future<void> registerWithUsername({
    required String username,
    required String password,
    required bool termsAccepted,
    required String termsVersion,
    required String privacyVersion,
  });

  /// Returns the signed-in user and whether this is their first time
  /// (no Firestore doc yet → caller should route to onboarding instead
  /// of straight into the app).
  Future<(AppUser user, bool isNewUser)> loginWithUsername({
    required String username,
    required String password,
  });

  /// Called once, right after first sign-in, to create the
  /// Firestore user document with the onboarding data.
  Future<AppUser> completeOnboarding({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    required String businessStatus,
    String? bio,
  });

  Future<void> signOut();

  /// True if [phoneNumber] (E.164) is already linked to a DIFFERENT
  /// account. A friendly pre-check before spending an SMS — the real,
  /// race-safe guarantee is still whatever [confirmPhoneLink] throws
  /// (Firebase Auth's own `credential-already-in-use`).
  Future<bool> isPhoneNumberTaken(String phoneNumber);

  /// Sends an SMS code for linking [phoneNumber] to the CURRENTLY
  /// signed-in account (never a sign-in by itself). Exactly one of
  /// [onCodeSent] or [onAutoVerified] fires per call — the latter only
  /// on Android's instant SMS auto-retrieval, in which case the link
  /// (and the Firestore `isVerified`/`phoneNumber` write) has already
  /// completed by the time it's called.
  Future<void> startPhoneLinkVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  });

  /// Confirms the SMS code, links it to the current account, and
  /// writes `isVerified: true` + `phoneNumber` to Firestore.
  Future<void> confirmPhoneLink({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  });

  /// Twilio Verify equivalent of [startPhoneLinkVerification] — sends
  /// the SMS via the `sendOtp` Cloud Function instead of Firebase's own
  /// phone auth. Gated behind `kUseTwilioOtp`; see
  /// [AccountVerificationScreen].
  Future<void> sendTwilioOtp(String phoneNumber);

  /// Twilio Verify equivalent of [confirmPhoneLink] — confirms via the
  /// `verifyOtp` Cloud Function, which writes `isVerified`/`phoneNumber`
  /// server-side and returns a custom token this then signs in with, so
  /// the CURRENTLY signed-in account ends up verified exactly like
  /// [confirmPhoneLink] leaves it.
  Future<void> verifyTwilioOtp({
    required String phoneNumber,
    required String code,
  });

  /// Sends an SMS code for the "Parolu unutdum" recovery path — never
  /// creates a new account. [phoneNumber] should already be known (via
  /// [isPhoneNumberTaken]) to belong to an existing account before
  /// calling this.
  Future<void> startPhoneRecoveryVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  });

  /// Confirms the code and signs in as whichever account [phoneNumber]
  /// is linked to (not the account that was signed in before, if any).
  /// Throws if the phone turns out not to be linked to any real
  /// account — see the implementation for why that matters.
  Future<void> confirmPhoneRecovery({
    required String verificationId,
    required String smsCode,
  });

  /// Changes the CURRENTLY signed-in user's password directly, no
  /// reauthentication — used right after [confirmPhoneRecovery]
  /// succeeds, where signing in via a fresh OTP already counts as
  /// strong recent authentication.
  Future<void> updatePassword(String newPassword);

  /// Re-authenticates with [currentPassword] before changing to
  /// [newPassword] — the normal in-session "Parolu dəyiş" path.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Renames the display username — a pure handle change. The
  /// sign-in credential (a random, never-shown synthetic email) is
  /// never derived from the username, so this never risks locking the
  /// account out: it copies that same credential pointer onto a new
  /// `usernames/{newUsername}` reservation and releases the old one.
  /// [oldUsername] stops being a valid login the instant this
  /// succeeds; only [newUsername] does from then on.
  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  });
}
