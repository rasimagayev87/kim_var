import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../legal/legal_versions.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
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

    return AppUser(
      id: user.uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      username: data['username'] as String?,
      email: data['email'] as String? ?? user.email,
      phone: data['phoneNumber'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      gender: data['gender'] as String?,
      loginProvider: _providerFrom(user),
    );
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
    await _writeUsernameReservationWithRetry(normalizedUsername.toLowerCase(), {
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': normalizedUsername,
      'loginProvider': _providerFrom(user).name,
      if (user.email != null) 'email': user.email,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      // Lowercase copy of the display name, kept in sync wherever
      // firstName/lastName can change (see `ProfileController.save`)
      // — lets the discover/search screen prefix-match names via a
      // plain Firestore range query, since Firestore can't do
      // case-insensitive matching on the raw display-cased fields.
      'nameLower': '$firstName $lastName'.trim().toLowerCase(),
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'bio': bio ?? '',
      'country': country,
      'city': city,
      'businessStatus': businessStatus,
      // The consent checkbox that gates the sign-in screen's 3
      // provider buttons (AuthScreen) already confirmed acceptance of
      // the CURRENT legal doc versions before this session's sign-in
      // even started — nothing else could have reached this point.
      'consent': {
        'termsAccepted': true,
        'acceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': kCurrentTermsVersion,
        'privacyVersion': kCurrentPrivacyVersion,
      },
      // `premium` is deliberately NOT set here — a grant-of-privilege
      // field firestore.rules forbids the client from ever writing
      // (even to its own default `false`), so the account doc simply
      // starts without it. Every read site already treats an absent
      // field as `false` (see UserProfile/premium_providers).
      'online': true,
      'friendCount': 0,
      'eventCount': 0,
      'blockedUsers': <String>[],
      'reportedCount': 0,
      'starCount': 0,
      'heartCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
