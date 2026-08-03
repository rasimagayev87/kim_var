import '../entities/app_user.dart';

typedef PhoneCodeSent = void Function(String verificationId);
typedef PhoneAutoVerified = void Function();
typedef PhoneVerificationFailed = void Function(String? errorCode);

/// Abstraction over the authentication backend (Firebase Auth).
///
/// Primary sign-in is username + password (Firebase Auth's
/// email/password provider under the hood, via a synthetic per-account
/// address — see [FirebaseAuthRepository]). Phone number is never used
/// to sign in directly; it backs two separate, secondary flows instead:
/// account recovery ("Parolu unutdum") and post-signup identity
/// verification ("Hesabı təsdiq et").
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

  Future<bool> isUsernameAvailable(String username);

  /// Creates the sign-in credential only. Does NOT create the
  /// Firestore user document and does NOT leave the caller signed
  /// in — the UI always routes to Login next; [completeOnboarding]
  /// is a separate, later step after the user logs in.
  Future<void> registerWithUsername({
    required String username,
    required String password,
  });

  /// Returns the signed-in user and whether onboarding still needs
  /// to run (no Firestore doc yet).
  Future<(AppUser user, bool needsOnboarding)> loginWithUsername({
    required String username,
    required String password,
  });

  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  });

  /// Called once, right after first login, to create the Firestore
  /// user document with the onboarding data.
  Future<AppUser> completeOnboarding({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    String? bio,
  });

  /// True if some account already reserved this phone number — used
  /// by both "Hesabı təsdiq et" (can't verify with a taken number) and
  /// "Parolu unutdum" (must find an existing account by number).
  Future<bool> isPhoneNumberTaken(String phoneNumber);

  /// Links [phoneNumber] to the CURRENTLY signed-in account
  /// ("Hesabı təsdiq et"). On success, the server-side
  /// `markPhoneVerified` call has already run.
  Future<void> startPhoneLinkVerification({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneAutoVerified onAutoVerified,
    required PhoneVerificationFailed onFailed,
  });

  Future<void> confirmPhoneLink({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  });

  /// Starts "Parolu unutdum" recovery — signs the caller in via the
  /// phone number's linked account once the SMS code is confirmed, so
  /// [updatePassword] can then be called.
  Future<void> startPhoneRecoveryVerification({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneAutoVerified onAutoVerified,
    required PhoneVerificationFailed onFailed,
  });

  Future<void> confirmPhoneRecovery({
    required String verificationId,
    required String smsCode,
  });

  /// Sets a new password for the currently signed-in user — the last
  /// step of "Parolu unutdum" recovery, right after
  /// [confirmPhoneRecovery] signs them in.
  Future<void> updatePassword(String newPassword);

  /// Changes the password for an already-authenticated user who
  /// still knows their current one ("Parolu dəyiş" in Ayarlar).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();
}
