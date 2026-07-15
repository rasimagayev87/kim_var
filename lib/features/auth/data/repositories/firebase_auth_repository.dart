import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production Firebase implementation of [AuthRepository]: Phone
/// (primary), Google, and Apple sign-in only — no email/password.
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
      phone: user.phoneNumber,
      loginProvider: _providerFrom(user),
    );
  }

  LoginProvider _providerFrom(fb.User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return LoginProvider.google;
      if (info.providerId == 'apple.com') return LoginProvider.apple;
    }
    return LoginProvider.phone;
  }

  Future<AppUser?> _hydrateFromFirestore(fb.User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data == null) return null;

    return AppUser(
      id: user.uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? user.email,
      phone: data['phoneNumber'] as String? ?? user.phoneNumber,
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
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneAutoVerified onAutoVerified,
    required PhoneVerificationFailed onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          final user = result.user!;
          final existing = await _hydrateFromFirestore(user);
          _needsOnboarding = existing == null;
          if (existing != null) _controller.add(existing);
          onAutoVerified(existing ?? _minimalAppUser(user), existing == null);
        } catch (e) {
          onFailed('Avtomatik təsdiqləmə uğursuz oldu: $e');
        }
      },
      verificationFailed: (e) {
        onFailed(e.message ?? 'Nömrə doğrulanmadı, yenidən cəhd edin.');
      },
      codeSent: (verificationId, resendToken) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<(AppUser, bool)> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;

    final existing = await _hydrateFromFirestore(user);
    _needsOnboarding = existing == null;
    if (existing != null) _controller.add(existing);

    return (existing ?? _minimalAppUser(user), existing == null);
  }

  @override
  Future<(AppUser, bool)> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw fb.FirebaseAuthException(code: 'cancelled', message: 'Google girişi ləğv edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;

    final existing = await _hydrateFromFirestore(user);
    _needsOnboarding = existing == null;
    if (existing != null) _controller.add(existing);

    return (existing ?? _minimalAppUser(user), existing == null);
  }

  @override
  Future<(AppUser, bool)> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oAuthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final result = await _auth.signInWithCredential(oAuthCredential);
    final user = result.user!;

    final existing = await _hydrateFromFirestore(user);
    _needsOnboarding = existing == null;

    // Apple only gives the name on the very first authorization —
    // capture it now in case the user completes onboarding with it
    // pre-filled (still editable).
    final appleFirstName = appleCredential.givenName;
    final appleLastName = appleCredential.familyName;

    if (existing != null) {
      _controller.add(existing);
      return (existing, false);
    }

    return (
      AppUser(
        id: user.uid,
        firstName: appleFirstName ?? '',
        lastName: appleLastName ?? '',
        email: appleCredential.email ?? user.email,
        loginProvider: LoginProvider.apple,
      ),
      true,
    );
  }

  @override
  Future<AppUser> completeOnboarding({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    String? bio,
    List<String> interests = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Onboarding tamamlanmazdan əvvəl giriş edilməlidir.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'phoneNumber': user.phoneNumber,
      'email': user.email,
      'loginProvider': _providerFrom(user).name,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'bio': bio ?? '',
      'interests': interests,
      'country': country,
      'city': city,
      'premium': false,
      'isVerified': true,
      'online': true,
      'friendCount': 0,
      'eventCount': 0,
      'blockedUsers': <String>[],
      'reportedCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _needsOnboarding = false;

    final appUser = AppUser(
      id: user.uid,
      firstName: firstName,
      lastName: lastName,
      email: user.email,
      phone: user.phoneNumber,
      birthDate: birthDate,
      gender: gender,
      loginProvider: _providerFrom(user),
    );
    _controller.add(appUser);
    return appUser;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _needsOnboarding = false;
    _controller.add(null);
  }
}
