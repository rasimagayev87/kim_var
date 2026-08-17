import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../domain/repositories/account_repository.dart';

/// Same key `FirebaseAuthRepository` parks the pending sign-in address
/// under — reused here so `EmailLinkSignInScreen` doesn't need to know
/// whether the link it's completing is a fresh sign-in or a
/// delete-account reauth; both cases read the same pref.
const _kPendingEmailLinkAddressKey = 'pendingEmailLinkAddress';

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn;

  static final _emailReauthCompletedController = StreamController<void>.broadcast();

  /// How recent "recent enough" means before attempting delete — well
  /// under Firebase's own (undocumented, server-enforced) threshold, so
  /// this pre-check fails safe: it may ask for reauth slightly more
  /// often than Firebase strictly requires, but it will never let a
  /// stale session reach the actual delete call below. The
  /// `deleteAccount` Cloud Function re-checks this same window
  /// server-side (see `functions/src/index.ts`) as defense-in-depth.
  static const _freshSignInWindow = Duration(minutes: 5);

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final lastSignIn = user.metadata.lastSignInTime;
    final isFresh = lastSignIn != null && DateTime.now().difference(lastSignIn) < _freshSignInWindow;
    if (!isFresh) {
      throw const ReauthenticationRequiredException();
    }

    try {
      await _functions.httpsCallable('deleteAccount').call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw const ReauthenticationRequiredException();
      }
      rethrow;
    }

    // The Cloud Function already deleted the Auth account server-side —
    // this local signOut() just clears the client's cached session
    // immediately, rather than waiting for the SDK to notice on its own
    // next token-refresh attempt (which isn't guaranteed to be prompt).
    await _auth.signOut();
  }

  @override
  Future<String> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('İxrac üçün istifadəçi daxil olmayıb.');

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = _sanitizeForJson(doc.data() ?? <String, dynamic>{});
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Firestore's `Timestamp`/`GeoPoint` etc. aren't directly
  /// JSON-encodable — walks the map/list tree converting anything
  /// `jsonEncode` would otherwise choke on into plain strings.
  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) return value.map((key, v) => MapEntry(key.toString(), _sanitizeForJson(v)));
    if (value is List) return value.map(_sanitizeForJson).toList();
    return value;
  }

  @override
  LoginProvider currentLoginProvider() {
    final user = _auth.currentUser;
    if (user != null) {
      for (final info in user.providerData) {
        if (info.providerId == 'google.com') return LoginProvider.google;
        if (info.providerId == 'apple.com') return LoginProvider.apple;
      }
    }
    return LoginProvider.email;
  }

  @override
  Future<void> reauthenticateWithApple() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Yenidən doğrulama üçün istifadəçi daxil olmayıb.');

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    // reauthenticateWithCredential — NOT signInWithCredential — refreshes
    // this same session's `lastSignInTime` without touching the app's
    // sign-in/onboarding auth-state stream at all.
    await user.reauthenticateWithCredential(oauthCredential);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Yenidən doğrulama üçün istifadəçi daxil olmayıb.');

    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) throw StateError('google-sign-in-cancelled');
    final googleAuth = await googleAccount.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> sendReauthEmailLink() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (email == null) throw StateError('Yenidən doğrulama üçün istifadəçinin e-poçtu yoxdur.');

    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: fb.ActionCodeSettings(
        url: 'https://peakpin.app/auth-email-link',
        handleCodeInApp: true,
        iOSBundleId: 'com.peakpin.app',
        androidPackageName: 'com.peakpin.app',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingEmailLinkAddressKey, email);
  }

  @override
  Future<void> reauthenticateWithEmailLink(String link) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('Yenidən doğrulama üçün istifadəçi daxil olmayıb.');
    }

    final credential = fb.EmailAuthProvider.credentialWithLink(email: email, emailLink: link);
    await user.reauthenticateWithCredential(credential);
    _emailReauthCompletedController.add(null);
  }

  @override
  Stream<void> get emailReauthCompleted => _emailReauthCompletedController.stream;

  @override
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('E-poçt yeniləmək üçün istifadəçi daxil olmayıb.');

    await _firestore.collection('users').doc(user.uid).set(
      {'email': newEmail, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
