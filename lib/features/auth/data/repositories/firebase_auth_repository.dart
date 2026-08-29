import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/private_data_ref.dart';
import '../../../legal/legal_versions.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final _controller = StreamController<AppUser?>.broadcast();
  bool _needsOnboarding = false;

  CollectionReference<Map<String, dynamic>> get _usernames => _firestore.collection('usernames');

  /// Firestore's SDK doesn't always finish propagating a just-changed
  /// auth context (a fresh sign-up right after a prior sign-out, most
  /// commonly) to its underlying connection before the very next write
  /// goes out — that write can land as a transient `permission-denied`
  /// even though the security rule is satisfied a moment later. Retries
  /// a couple of times with a short backoff before giving up for real.
  Future<void> _writeUsernameReservationWithRetry(String usernameId, Map<String, dynamic> data) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _usernames.doc(usernameId).set(data);
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  @override
  bool get needsOnboarding => _needsOnboarding;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _minimalAppUser(user);
  }

  AppUser _minimalAppUser(fb.User user) {
    return AppUser(
      id: user.uid,
      firstName: '',
      lastName: '',
      email: user.email,
      loginProvider: _providerFrom(user),
    );
  }

  LoginProvider _providerFrom(fb.User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return LoginProvider.google;
      if (info.providerId == 'apple.com') return LoginProvider.apple;
    }
    return LoginProvider.email;
  }

  Future<AppUser?> _hydrateFromFirestore(fb.User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    // NOT just `data == null` — several other providers (location,
    // presence, device-signature tracking, the legal-consent dialog)
    // merge-write their own fields onto `users/{uid}` the moment a
    // session exists, independent of onboarding. If any of those races
    // ahead of completeOnboarding (confirmed happening: a slow
    // cold-started `notifyOnNewDeviceSignIn` invocation once created
    // this doc before the client-side new-user check ever ran), a
    // pure existence check would wrongly read as "onboarding done" and
    // skip it entirely. `username` is only ever set by
    // completeOnboarding, so it's the one field that actually means a
    // profile was completed.
    if (data == null || data['username'] == null) return null;

    // `phoneNumber`/`birthDate`/`gender` moved to `users/{uid}/private/
    // data` (Düzəliş Prompt 4) — this is a self-read (the signed-in
    // user's own doc), always allowed.
    final privateData = (await privateDataRef(user.uid, firestore: _firestore).get()).data() ?? {};

    unawaited(_maybeWriteVersionTelemetry(user.uid, privateData));

    return AppUser(
      id: user.uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      username: data['username'] as String?,
      email: (privateData['email'] as String?) ?? user.email,
      phone: privateData['phoneNumber'] as String?,
      birthDate: (privateData['birthDate'] as Timestamp?)?.toDate(),
      gender: privateData['gender'] as String?,
      loginProvider: _providerFrom(user),
    );
  }

  /// Writes `appVersion`/`buildNumber`/`platform`/`osVersion`/
  /// `lastSeenAt` onto `users/{uid}/private/data` (Düzəliş Prompt 4) —
  /// but only when the installed version has actually changed since
  /// [existingPrivateData] was last written, or it's been >24h since
  /// [existingPrivateData]'s own `lastSeenAt`, not on every single
  /// restore/resume. This is the only source of "which app version is
  /// actually still out there" (see the admin panel's version-breakdown
  /// view, planned separately) that the post-launch backward-
  /// compatibility policy depends on to decide when it's safe to drop a
  /// legacy field — best-effort, never surfaced as an error to the caller.
  Future<void> _maybeWriteVersionTelemetry(String uid, Map<String, dynamic> existingPrivateData) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final storedVersion = existingPrivateData['appVersion'] as String?;
      final storedLastSeenAt = existingPrivateData['lastSeenAt'] as Timestamp?;
      final staleByTime =
          storedLastSeenAt == null || DateTime.now().difference(storedLastSeenAt.toDate()) > const Duration(hours: 24);

      if (storedVersion == currentVersion && !staleByTime) return;

      await privateDataRef(uid, firestore: _firestore).set({
        'appVersion': currentVersion,
        'buildNumber': info.buildNumber,
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      logError('firebase_auth_repository._maybeWriteVersionTelemetry', e, st);
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final appUser = await _hydrateFromFirestore(user);
    if (appUser == null) {
      _needsOnboarding = true;
      return null;
    }

    _needsOnboarding = false;
    _controller.add(appUser);
    return appUser;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _usernames.doc(username.trim().toLowerCase()).get();
    return !doc.exists;
  }

  /// Shared by every sign-in method below — resolves whichever
  /// Firebase user the credential produced into an [AppUser], and
  /// flags [needsOnboarding] the same way for all 3 providers.
  Future<(AppUser, bool)> _afterSignIn(fb.User user) async {
    final existing = await _hydrateFromFirestore(user);
    _needsOnboarding = existing == null;
    if (existing != null) _controller.add(existing);
    return (existing ?? _minimalAppUser(user), existing == null);
  }

  @override
  Future<(AppUser, bool)> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(oauthCredential);
    return _afterSignIn(result.user!);
  }

  @override
  Future<(AppUser, bool)> signInWithGoogle() async {
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) {
      throw StateError('google-sign-in-cancelled');
    }
    final googleAuth = await googleAccount.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return _afterSignIn(result.user!);
  }

  @override
  Future<(AppUser, bool)> signInWithEmailPassword(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _afterSignIn(result.user!);
  }

  @override
  Future<(AppUser, bool)> registerWithEmailPassword(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    // Best-effort: nothing today actually confirms the typed address is
    // real/owned by this person (Apple/Google sign-in don't have this
    // gap — those emails are already provider-verified). A failed send
    // here shouldn't block registration itself; the account exists
    // either way, so this never blocks or rethrows.
    unawaited(result.user!.sendEmailVerification());
    return _afterSignIn(result.user!);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('E-poçt təsdiqini yenidən göndərmək üçün giriş edilməlidir.');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Username dəyişmək üçün əvvəlcə giriş edilməlidir.');
    }

    final oldLower = oldUsername.trim().toLowerCase();
    final normalizedNew = newUsername.trim();
    final newLower = normalizedNew.toLowerCase();
    if (oldLower == newLower) return;

    await _writeUsernameReservationWithRetry(newLower, {
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'username': normalizedNew,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _usernames.doc(oldLower).delete();
    } catch (_) {
      // Best-effort — an orphaned old reservation just permanently
      // holds that username, it doesn't break this account (its new
      // reservation is already live and Firestore is updated).
    }
  }

  @override
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
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Onboarding tamamlanmazdan əvvəl giriş edilməlidir.');
    }

    final normalizedUsername = username.trim();

    // The `users/{uid}` document is created server-side now, not written
    // directly here — `completeOnboarding` (Cloud Function) is the ONLY
    // place the minimum-age check (18+) can run somewhere a modified
    // client can't skip; see that function's own doc comment. It also
    // reserves the username atomically (one transaction, not the
    // two-step reservation-then-profile-write this used to be), and is
    // idempotent — a retried call after a dropped response is a no-op
    // success, not a duplicate-create error.
    try {
      await _functions.httpsCallable('completeOnboarding').call<Map<String, dynamic>>({
        'username': normalizedUsername,
        'firstName': firstName,
        'lastName': lastName,
        'birthDateMs': birthDate.millisecondsSinceEpoch,
        'gender': gender,
        'country': country,
        'city': city,
        'phoneNumber': phoneNumber,
        'businessStatus': businessStatus,
        'bio': bio ?? '',
        // The consent checkbox that gates the sign-in screen's 3
        // provider buttons (AuthScreen) already confirmed acceptance of
        // the CURRENT legal doc versions before this session's sign-in
        // even started — nothing else could have reached this point.
        'termsVersion': kCurrentTermsVersion,
        'privacyVersion': kCurrentPrivacyVersion,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw const UnderageOnboardingException();
      }
      if (e.code == 'permission-denied' && e.message == 'email-not-verified') {
        throw const EmailNotVerifiedException();
      }
      rethrow;
    }

    _needsOnboarding = false;

    final appUser = AppUser(
      id: user.uid,
      firstName: firstName,
      lastName: lastName,
      username: normalizedUsername,
      email: user.email,
      phone: phoneNumber,
      birthDate: birthDate,
      gender: gender,
      loginProvider: _providerFrom(user),
    );
    _controller.add(appUser);
    return appUser;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _needsOnboarding = false;
    _controller.add(null);
  }
}
