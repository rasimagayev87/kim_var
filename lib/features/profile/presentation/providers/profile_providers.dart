import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';

/// Firestore is the source of truth for the profile. SharedPreferences
/// is used ONLY as a local cache so the UI can paint instantly on
/// app start (before the first Firestore snapshot arrives) and to
/// stay usable very briefly offline — every write always goes to
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
  static const _keyBirthDate = 'profile_cache_birth_date';
  static const _keyGender = 'profile_cache_gender';
  static const _keyCountry = 'profile_cache_country';
  static const _keyCity = 'profile_cache_city';
  static const _keyEmail = 'profile_cache_email';

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  ProfileController({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        super(const UserProfile()) {
    _init();
  }

  Future<void> _init() async {
    final cached = await _readCache();
    if (cached != null) state = cached;

    _auth.authStateChanges().listen((user) {
      _subscription?.cancel();
      if (user == null) {
        state = const UserProfile();
        return;
      }

      _subscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        final profile = _fromDocData(doc.data());
        state = profile;
        _writeCache(profile);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  UserProfile _fromDocData(Map<String, dynamic>? data) {
    if (data == null) return const UserProfile();
    return UserProfile(
      username: data['username'] as String?,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      gender: data['gender'] as String?,
      country: data['country'] as String?,
      city: data['city'] as String?,
      email: data['email'] as String?,
      online: data['online'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      heartCount: (data['heartCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      identityVerified: data['identityVerified'] as bool? ?? false,
      businessStatus: data['businessStatus'] as String?,
    );
  }

  Future<UserProfile?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final bio = prefs.getString(_keyBio);
    if (bio == null) return null;
    return UserProfile(
      photoUrl: prefs.getString(_keyPhotoUrl),
      bio: bio,
      birthDate: prefs.containsKey(_keyBirthDate)
          ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_keyBirthDate)!)
          : null,
      gender: prefs.getString(_keyGender),
      country: prefs.getString(_keyCountry),
      city: prefs.getString(_keyCity),
      email: prefs.getString(_keyEmail),
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
      await prefs.setInt(_keyBirthDate, profile.birthDate!.millisecondsSinceEpoch);
    }
    if (profile.gender != null) await prefs.setString(_keyGender, profile.gender!);
    if (profile.country != null) await prefs.setString(_keyCountry, profile.country!);
    if (profile.city != null) await prefs.setString(_keyCity, profile.city!);
    if (profile.email != null) await prefs.setString(_keyEmail, profile.email!);
  }

  /// Writes the "Şəxsi məlumatlar" fields to the user's Firestore
  /// document. The photo is handled separately by [updatePhotoUrl] —
  /// see `PhotoUploadController` in `photo_upload_provider.dart`,
  /// which uploads to Firebase Storage first and then calls that
  /// method. Username is handled separately too, via
  /// `AuthController.updateUsername` — it needs the `usernames`
  /// reservation-swap dance, not a plain field write.
  ///
  /// There is no `age` parameter: age is always derived from
  /// [birthDate] — see [UserProfile.age].
  Future<void> save({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String bio,
    String? gender,
    String? country,
    String? city,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set(
      {
        'firstName': firstName,
        'lastName': lastName,
        'nameLower': '$firstName $lastName'.trim().toLowerCase(),
        'birthDate': Timestamp.fromDate(birthDate),
        'bio': bio,
        if (gender != null) 'gender': gender,
        if (country != null) 'country': country,
        if (city != null) 'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // `state` updates automatically via the live Firestore listener above.
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
