import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/private_data_ref.dart';
import '../../domain/entities/user_profile.dart';

/// Firestore is the source of truth for the profile. SharedPreferences/
/// secure storage are used ONLY as a local cache so the UI can paint
/// instantly on app start (before the first Firestore snapshot arrives)
/// and to stay usable very briefly offline — every write always goes to
/// Firestore first.
final profileControllerProvider =
    StateNotifierProvider<ProfileController, UserProfile>((ref) {
  return ProfileController();
});

/// Single source of truth for "does the current user currently have
/// business access" — wraps [UserProfile.hasBusinessAccess] so every
/// gate that depends on it (e.g. the business-offer acceptance step in
/// venue creation) reads through one provider instead of re-deriving
/// the condition at each call site.
final hasBusinessAccessProvider = Provider<bool>((ref) {
  return ref.watch(profileControllerProvider).hasBusinessAccess;
});

class ProfileController extends StateNotifier<UserProfile> {
  static const _keyPhotoUrl = 'profile_cache_photo_url';
  static const _keyBio = 'profile_cache_bio';
  static const _keyGender = 'profile_cache_gender';
  static const _keyCountry = 'profile_cache_country';
  static const _keyCity = 'profile_cache_city';

  // Düzəliş Prompt 4 / INFRA-40 — email/birthDate moved to secure
  // storage (Keystore/Keychain-backed), the two most sensitive fields
  // this cache held in plaintext. `bio`/`gender`/`country`/`city`/
  // `photoUrl` stay in plain SharedPreferences — migrating them too
  // wouldn't meaningfully reduce exposure (a display name/photo URL
  // isn't the same class of sensitive as an exact birth date).
  static const _secureKeyBirthDate = 'profile_cache_birth_date';
  static const _secureKeyEmail = 'profile_cache_email';

  // Pre-Prompt-4 plaintext keys these two fields used to live under —
  // purged on first read so a device that already had this app
  // installed doesn't keep a stale plaintext copy sitting in
  // SharedPreferences forever after the upgrade.
  static const _legacyKeyBirthDate = 'profile_cache_birth_date_legacy_plaintext';
  static const _legacyKeyEmail = 'profile_cache_email_legacy_plaintext';

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FlutterSecureStorage _secureStorage;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _publicSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _privateSubscription;
  Map<String, dynamic>? _latestPublicData;
  Map<String, dynamic>? _latestPrivateData;

  final FirebaseFunctions _functions;

  ProfileController({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FlutterSecureStorage? secureStorage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _functions = functions ?? FirebaseFunctions.instance,
        super(const UserProfile()) {
    _init();
  }

  Future<void> _init() async {
    final cached = await _readCache();
    if (cached != null) state = cached;

    _auth.authStateChanges().listen((user) {
      _publicSubscription?.cancel();
      _privateSubscription?.cancel();
      _latestPublicData = null;
      _latestPrivateData = null;
      if (user == null) {
        state = const UserProfile();
        return;
      }

      // Two documents, one merged state — `users/{uid}/private/data`
      // (Düzəliş Prompt 4) holds birthDate/gender/city/email now. Each
      // listener updates its own cached half and re-emits the combined
      // profile; the very first emit can briefly lag on whichever
      // document's snapshot arrives second (usually milliseconds), the
      // same kind of transient a single listener already had before
      // its own first snapshot arrived.
      _publicSubscription =
          _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        _latestPublicData = doc.data();
        _emit();
      });
      _privateSubscription =
          privateDataRef(user.uid, firestore: _firestore).snapshots().listen((doc) {
        _latestPrivateData = doc.data();
        _emit();
      });
    });
  }

  void _emit() {
    final profile = _fromDocData(_latestPublicData, _latestPrivateData);
    state = profile;
    _writeCache(profile);
  }

  @override
  void dispose() {
    _publicSubscription?.cancel();
    _privateSubscription?.cancel();
    super.dispose();
  }

  UserProfile _fromDocData(Map<String, dynamic>? publicData, Map<String, dynamic>? privateData) {
    if (publicData == null) return const UserProfile();
    return UserProfile(
      username: publicData['username'] as String?,
      firstName: publicData['firstName'] as String? ?? '',
      lastName: publicData['lastName'] as String? ?? '',
      photoUrl: publicData['photoUrl'] as String?,
      bio: publicData['bio'] as String? ?? '',
      birthDate: (privateData?['birthDate'] as Timestamp?)?.toDate(),
      gender: privateData?['gender'] as String?,
      country: publicData['country'] as String?,
      city: privateData?['city'] as String?,
      email: privateData?['email'] as String?,
      phoneNumber: privateData?['phoneNumber'] as String?,
      online: publicData['online'] as bool? ?? false,
      lastSeen: (publicData['lastSeen'] as Timestamp?)?.toDate(),
      identityVerified: publicData['identityVerified'] as bool? ?? false,
      businessStatus: publicData['businessStatus'] as String?,
    );
  }

  Future<UserProfile?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final bio = prefs.getString(_keyBio);
    if (bio == null) return null;

    // One-time purge of the pre-Prompt-4 plaintext copies, if any
    // survive from before this device's app update.
    if (prefs.containsKey(_legacyKeyBirthDate) || prefs.containsKey(_legacyKeyEmail)) {
      await prefs.remove(_legacyKeyBirthDate);
      await prefs.remove(_legacyKeyEmail);
    }

    final birthDateMs = await _secureStorage.read(key: _secureKeyBirthDate);
    final email = await _secureStorage.read(key: _secureKeyEmail);
    return UserProfile(
      photoUrl: prefs.getString(_keyPhotoUrl),
      bio: bio,
      birthDate: birthDateMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.parse(birthDateMs)),
      gender: prefs.getString(_keyGender),
      country: prefs.getString(_keyCountry),
      city: prefs.getString(_keyCity),
      email: email,
    );
  }

  Future<void> _writeCache(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile.photoUrl != null) {
      await prefs.setString(_keyPhotoUrl, profile.photoUrl!);
    } else {
      await prefs.remove(_keyPhotoUrl);
    }
    await prefs.setString(_keyBio, profile.bio);
    if (profile.birthDate != null) {
      await _secureStorage.write(
        key: _secureKeyBirthDate,
        value: profile.birthDate!.millisecondsSinceEpoch.toString(),
      );
    }
    if (profile.gender != null) await prefs.setString(_keyGender, profile.gender!);
    if (profile.country != null) await prefs.setString(_keyCountry, profile.country!);
    if (profile.city != null) await prefs.setString(_keyCity, profile.city!);
    if (profile.email != null) await _secureStorage.write(key: _secureKeyEmail, value: profile.email!);
  }

  /// Writes the "Şəxsi məlumatlar" fields through `updateProfileDetails`
  /// (Cloud Function) rather than writing Firestore directly.
  ///
  /// It used to be a two-document `WriteBatch`, with the username
  /// handled separately by `AuthController.updateUsername` beforehand.
  /// That shape had to go for two reasons:
  ///
  ///   * `firstName`/`lastName`/`nameLower`/`username` are now locked in
  ///     `firestore.rules` (`touchesLockedUserFields()`), and
  ///     `birthDate`/`phoneNumber` in the private doc's
  ///     `serverOnlyFields()`. A direct write is rejected outright.
  ///   * Running the username swap first and the batch second meant a
  ///     failure in the second step left the account with a new handle
  ///     and the old name. The callable commits every field in one
  ///     transaction — all of it, or none.
  ///
  /// Errors arrive as `FirebaseFunctionsException.message`, already a
  /// full Azerbaijani sentence naming the field and the wait (see
  /// `updateProfileDetails`). Callers should show it verbatim rather
  /// than mapping it to a generic failure string.
  ///
  /// Only CHANGED values should be passed: every argument is optional
  /// and an omitted one is left untouched server-side, which is also
  /// what keeps an unchanged `birthDate` from burning its one allowed
  /// correction.
  Future<void> save({
    String? firstName,
    String? lastName,
    String? username,
    DateTime? birthDate,
    String? bio,
    String? gender,
    String? country,
    String? city,
    String? phoneNumber,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _functions.httpsCallable('updateProfileDetails').call<Map<String, dynamic>>({
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (username != null) 'username': username,
      if (birthDate != null) 'birthDateMs': birthDate.millisecondsSinceEpoch,
      if (bio != null) 'bio': bio,
      if (gender != null) 'gender': gender,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });
    // `state` updates automatically via the live Firestore listeners above.
  }

  /// Persists a new profile photo URL (or `null` to clear it) to the
  /// user's Firestore document. Called by `PhotoUploadController` after
  /// a successful Firebase Storage upload/delete.
  Future<void> updatePhotoUrl(String? photoUrl) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set(
      {
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // `state` updates automatically via the live Firestore listener above.
  }

  /// "Biznes fəaliyyəti" — the user can flip this freely, any time, no
  /// approval needed (see `PrivacySecurityScreen`). Only ever changes
  /// future venue/offer-*creation* access (gated client-side by
  /// `hasBusinessAccess`, server-side by `isBusinessUser` in
  /// firestore.rules) — existing venues/offers are never touched here.
  Future<bool> updateBusinessStatus(String value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'businessStatus': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (_) {
      return false;
    }
    // `state` updates automatically via the live Firestore listener above.
  }
}
