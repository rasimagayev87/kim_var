import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/repositories/account_repository.dart';

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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
  Future<void> sendReauthCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          await _auth.currentUser?.reauthenticateWithCredential(credential);
        } catch (_) {
          onFailed();
        }
      },
      verificationFailed: (_) => onFailed(),
      codeSent: (verificationId, resendToken) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<void> confirmReauthCode({required String verificationId, required String smsCode}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Yenidən doğrulama üçün istifadəçi daxil olmayıb.');

    final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    // reauthenticateWithCredential — NOT signInWithCredential — refreshes
    // this same session's `lastSignInTime` without touching the app's
    // sign-in/onboarding auth-state stream at all.
    await user.reauthenticateWithCredential(credential);
  }

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
