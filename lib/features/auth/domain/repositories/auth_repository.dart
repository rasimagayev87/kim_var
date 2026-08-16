import '../entities/app_user.dart';

/// Abstraction over the authentication backend (Firebase Auth).
///
/// Sign-in is exactly 3 methods — Apple, Google, or a passwordless
/// E-mail Link — never a password of any kind. Each returns whether
/// the account is brand new (caller should route to
/// [AuthRepository.completeOnboarding]) or already exists. A separate
/// public `@username` handle is still collected during onboarding
/// (see [isUsernameAvailable]/[updateUsername]) — purely a display
/// name, never a sign-in credential.
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

  /// Sends a passwordless sign-in link to [email] (Firebase's Email
  /// Link Sign-In — `sendSignInLinkToEmail`). The link opens
  /// `https://peakpin.app/auth-email-link`, which this app already
  /// intercepts as a Universal Link (see `deep_link_handler.dart`) —
  /// no new domain/entitlement setup needed.
  Future<void> sendEmailSignInLink(String email);

  /// True if [link] is a Firebase email sign-in link — the deep-link
  /// handler uses this to tell an email-link open apart from any
  /// other Universal Link this app handles.
  bool isEmailSignInLink(String link);

  /// Completes email-link sign-in. [email] must be the SAME address
  /// [sendEmailSignInLink] was called with — Firebase itself doesn't
  /// carry it inside the link, so the caller re-supplies it (see
  /// where it's persisted for this purpose in the implementation).
  Future<(AppUser user, bool isNewUser)> signInWithEmailLink({
    required String email,
    required String link,
  });

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

  /// Renames the display username — a pure handle change with no
  /// effect on sign-in (there's no credential to touch — see this
  /// class's own doc comment). [oldUsername] stops resolving the
  /// instant this succeeds; only [newUsername] does from then on.
  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  });
}
