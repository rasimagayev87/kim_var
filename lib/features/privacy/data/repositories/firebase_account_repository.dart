import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../domain/repositories/account_repository.dart';

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

  /// Notifications are the one collection here that can genuinely grow
  /// unbounded for an active account — capped to the most recent 200
  /// (still far more than the in-app feed itself ever pages through at
  /// once) so this stays a single reasonably-sized read rather than an
  /// unbounded one; every other collection here is realistically small
  /// enough not to need a cap.
  static const _notificationsExportLimit = 200;

  @override
  Future<String> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('İxrac üçün istifadəçi daxil olmayıb.');
    final uid = user.uid;

    final results = await Future.wait([
      _firestore.collection('users').doc(uid).get(),
      _firestore.collection('posts').where('userId', isEqualTo: uid).get(),
      _firestore.collection('reviews').where('userId', isEqualTo: uid).get(),
      _firestore.collection('users').doc(uid).collection('payments').orderBy('createdAt', descending: true).get(),
      _firestore.collection('savedCards').where('ownerId', isEqualTo: uid).where('status', isEqualTo: 'active').get(),
      _firestore.collection('follows').where('followerId', isEqualTo: uid).get(),
      _firestore.collection('follows').where('followeeId', isEqualTo: uid).get(),
      _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(_notificationsExportLimit)
          .get(),
    ]);

    final profileDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final postsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final reviewsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final paymentsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final savedCardsSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final followingSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final followersSnap = results[6] as QuerySnapshot<Map<String, dynamic>>;
    final notificationsSnap = results[7] as QuerySnapshot<Map<String, dynamic>>;

    final export = <String, dynamic>{
      'profile': profileDoc.data() ?? <String, dynamic>{},
      'posts': postsSnap.docs.map((d) => d.data()).toList(),
      'reviews': reviewsSnap.docs.map((d) => d.data()).toList(),
      'paymentHistory': paymentsSnap.docs.map((d) => d.data()).toList(),
      // Never the real Epoint card token — only what's already shown
      // in "Kartlarım" itself.
      'savedCards': savedCardsSnap.docs
          .map((d) => {'cardMask': d.data()['cardMask'], 'cardBrand': d.data()['cardBrand'], 'isDefault': d.data()['isDefault']})
          .toList(),
      'following': followingSnap.docs.map((d) => d.data()['followeeId']).toList(),
      'followers': followersSnap.docs.map((d) => d.data()['followerId']).toList(),
      'notifications': notificationsSnap.docs.map((d) => d.data()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(_sanitizeForJson(export));
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
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('Yenidən doğrulama üçün istifadəçi daxil olmayıb.');
    }

    final credential = fb.EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('E-poçt yeniləmək üçün istifadəçi daxil olmayıb.');

    final lastSignIn = user.metadata.lastSignInTime;
    final isFresh = lastSignIn != null && DateTime.now().difference(lastSignIn) < _freshSignInWindow;
    if (!isFresh) {
      throw const ReauthenticationRequiredException();
    }

    try {
      await user.verifyBeforeUpdateEmail(newEmail);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const ReauthenticationRequiredException();
      }
      rethrow;
    }
  }

  @override
  Future<void> syncEmailFromAuth() async {
    final userBefore = _auth.currentUser;
    if (userBefore == null) return;

    try {
      await userBefore.reload();
    } catch (_) {
      // Best-effort — a transient reload failure just means this run
      // doesn't catch a pending change; the next app launch will retry.
      return;
    }

    final user = _auth.currentUser;
    final authEmail = user?.email;
    if (user == null || authEmail == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final storedEmail = doc.data()?['email'] as String?;
    if (storedEmail == authEmail) return;

    await _firestore.collection('users').doc(user.uid).set(
      {'email': authEmail, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
