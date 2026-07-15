import '../entities/app_user.dart';

typedef PhoneAutoVerified = void Function(AppUser user, bool isNewUser);
typedef PhoneCodeSent = void Function(String verificationId);
typedef PhoneVerificationFailed = void Function(String message);

/// Abstraction over the authentication backend (Firebase Auth).
///
/// Three sign-in methods only: Phone (primary), Google, Apple
/// (iOS-only). There is no email/password flow — email is an
/// optional profile field, never used to sign in.
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

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneAutoVerified onAutoVerified,
    required PhoneVerificationFailed onFailed,
  });

  /// Confirms the SMS code. Returns the signed-in user and whether
  /// this is their first time (no Firestore doc yet → caller should
  /// route to onboarding instead of straight into the app).
  Future<(AppUser user, bool isNewUser)> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  });

  Future<(AppUser user, bool isNewUser)> signInWithGoogle();

  /// Only meaningful on iOS.
  Future<(AppUser user, bool isNewUser)> signInWithApple();

  /// Called once, right after first sign-in, to create the
  /// Firestore user document with the onboarding data.
  Future<AppUser> completeOnboarding({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    String? bio,
    List<String> interests = const [],
  });

  Future<void> signOut();
}
