import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final _controller = StreamController<AppUser?>.broadcast();
  bool _needsOnboarding = false;

  /// Firebase Auth's email/password provider is reused as the backing
  /// credential store for username sign-in — there's no native
  /// "username" provider. Deliberately NOT derived from the username
  /// (a client-generated random id instead, via Firestore's local
  /// auto-id generator — no network call) so a later username rename
  /// never touches the actual sign-in credential; login instead
  /// resolves username → this address via the `usernames` doc. Never
  /// shown to the user and never written to their profile's real
  /// `email` field.
  String _randomAuthEmail() {
    // Firestore's auto-id is mixed-case; Firebase Auth normalizes emails
    // to lowercase on creation regardless, so the `usernames` doc must
    // store the same lowercase form it will actually be matched against.
    final randomId = _firestore.collection('_').doc().id.toLowerCase();
    return '$randomId@users.meevima.app';
  }

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
      username: user.displayName,
      phone: user.phoneNumber,
      loginProvider: _providerFrom(user),
    );
  }

  LoginProvider _providerFrom(fb.User user) {
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return LoginProvider.google;
      if (info.providerId == 'apple.com') return LoginProvider.apple;
    }
    return LoginProvider.password;
  }

  Future<AppUser?> _hydrateFromFirestore(fb.User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data == null) return null;

    return AppUser(
      id: user.uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      username: data['username'] as String? ?? user.displayName,
      // The real, user-set contact email lives only in this Firestore
      // field (written via Settings → Account → Email) — never falls
      // back to `user.email`, which is the synthetic sign-in address.
      email: data['email'] as String?,
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
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _usernames.doc(username.trim().toLowerCase()).get();
    return !doc.exists;
  }

  @override
  Future<void> registerWithUsername({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim();
    final authEmail = _randomAuthEmail();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: authEmail,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(normalized);
    try {
      await _writeUsernameReservationWithRetry(
        normalized.toLowerCase(),
        {
          'uid': user.uid,
          'authEmail': authEmail,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    } finally {
      // Registration never leaves the caller signed in — the UI
      // always routes to Login next, regardless of whether the
      // best-effort username-reservation write above succeeded.
      await _auth.signOut();
    }
  }

  @override
  Future<(AppUser, bool)> loginWithUsername({
    required String username,
    required String password,
  }) async {
    final usernameDoc = await _usernames.doc(username.trim().toLowerCase()).get();
    final authEmail = usernameDoc.data()?['authEmail'] as String?;
    if (authEmail == null) {
      throw StateError('username-not-found');
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );
    final user = credential.user!;

    final existing = await _hydrateFromFirestore(user);
    _needsOnboarding = existing == null;
    if (existing != null) _controller.add(existing);

    return (existing ?? _minimalAppUser(user), existing == null);
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

    final oldDoc = await _usernames.doc(oldLower).get();
    final authEmail = oldDoc.data()?['authEmail'] as String?;
    if (authEmail == null) {
      throw StateError('Cari username tapılmadı.');
    }

    await _writeUsernameReservationWithRetry(newLower, {
      'uid': user.uid,
      'authEmail': authEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await user.updateDisplayName(normalizedNew);
    await _firestore.collection('users').doc(user.uid).update({
      'username': normalizedNew,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _usernames.doc(oldLower).delete();
    } catch (_) {
      // Best-effort — an orphaned old reservation just permanently
      // holds that username, it doesn't break this account (its new
      // reservation is already live and Auth/Firestore are updated).
    }
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
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Onboarding tamamlanmazdan əvvəl giriş edilməlidir.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': user.displayName,
      'loginProvider': _providerFrom(user).name,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'bio': bio ?? '',
      'country': country,
      'city': city,
      // `premium`/`isVerified` are deliberately NOT set here — both are
      // grant-of-privilege fields firestore.rules forbids the client
      // from ever writing (even to their own default `false`), so the
      // account doc simply starts without them. Every read site already
      // treats an absent field as `false` (see UserProfile/premium_
      // providers), and `isVerified` only ever flips to `true` via the
      // server-side markPhoneVerified Cloud Function once phone-linking
      // ("Hesabı təsdiq et") actually succeeds.
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
      username: user.displayName,
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
    _needsOnboarding = false;
    _controller.add(null);
  }

  /// Public, get-only phone → uid reservation (mirrors [_usernames]) —
  /// deliberately NOT a query against `users.phoneNumber`, because
  /// that field is only readable by signed-in users (see
  /// firestore.rules), and [isPhoneNumberTaken] must work for the
  /// "Parolu unutdum" flow BEFORE the caller is signed in.
  CollectionReference<Map<String, dynamic>> get _phoneNumbers => _firestore.collection('phoneNumbers');

  @override
  Future<bool> isPhoneNumberTaken(String phoneNumber) async {
    final doc = await _phoneNumbers.doc(phoneNumber).get();
    return doc.exists;
  }

  @override
  Future<void> startPhoneLinkVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  }) async {
    // On some devices/networks, none of verificationCompleted,
    // verificationFailed, or codeSent ever fire (a stuck Play
    // Integrity/reCAPTCHA challenge, a blocked Google API endpoint,
    // etc.) — without this guard, the caller's loading spinner would
    // spin forever with no feedback at all. codeAutoRetrievalTimeout
    // fires unconditionally ~60s later regardless of outcome, so it
    // only treats that as a failure when nothing else already settled.
    var settled = false;
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        settled = true;
        try {
          await _linkAndMarkVerified(credential, phoneNumber);
          onAutoVerified();
        } on fb.FirebaseAuthException catch (e) {
          onFailed(e.code);
        } catch (_) {
          onFailed(null);
        }
      },
      verificationFailed: (e) {
        settled = true;
        onFailed(e.code);
      },
      codeSent: (verificationId, resendToken) {
        settled = true;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {
        if (!settled) onFailed(null);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<void> confirmPhoneLink({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _linkAndMarkVerified(credential, phoneNumber);
  }

  Future<void> _linkAndMarkVerified(fb.PhoneAuthCredential credential, String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Təsdiqləmə üçün əvvəlcə giriş edilməlidir.');
    }
    await user.linkWithCredential(credential);
    // `isVerified`/`phoneNumber` on users/{uid} (and the phoneNumbers/
    // reservation doc) are written server-side by this callable, not
    // by a direct Firestore write — firestore.rules blocks the client
    // from setting isVerified itself, specifically so a raw Firestore
    // write can't self-grant verification. The function trusts Firebase
    // Auth's OWN phoneNumber claim (just set by linkWithCredential
    // above via a real SMS OTP), never anything the client passes in.
    await _functions.httpsCallable('markPhoneVerified').call<Map<String, dynamic>>();
  }

  @override
  Future<void> startPhoneRecoveryVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  }) async {
    // See the identical guard in [startPhoneLinkVerification] — some
    // devices/networks never invoke any of the other three callbacks,
    // which would otherwise leave the caller's loading spinner stuck
    // forever with no feedback.
    var settled = false;
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        settled = true;
        try {
          await _signInForRecovery(credential);
          onAutoVerified();
        } on fb.FirebaseAuthException catch (e) {
          onFailed(e.code);
        } catch (_) {
          onFailed(null);
        }
      },
      verificationFailed: (e) {
        settled = true;
        onFailed(e.code);
      },
      codeSent: (verificationId, resendToken) {
        settled = true;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {
        if (!settled) onFailed(null);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<void> confirmPhoneRecovery({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _signInForRecovery(credential);
  }

  /// Signing in with a phone credential that ISN'T already linked to
  /// any account doesn't fail — Firebase Auth just creates a brand
  /// new one for it. That would be silently wrong here (the caller
  /// asked to recover a specific existing account, having already
  /// confirmed via [isPhoneNumberTaken] that one exists), so this
  /// checks the resulting uid actually has a matching Firestore
  /// profile and undoes the sign-in otherwise.
  Future<void> _signInForRecovery(fb.PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;
    final existing = await _hydrateFromFirestore(user);
    if (existing == null) {
      await _auth.signOut();
      throw StateError('phone-not-registered');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Parolu yeniləmək üçün əvvəlcə giriş edilməlidir.');
    }
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Parolu dəyişmək üçün əvvəlcə giriş edilməlidir.');
    }
    final credential = fb.EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
