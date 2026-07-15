import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
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

class ProfileController extends StateNotifier<UserProfile> {
  static const _keyPhotoUrl = 'profile_cache_photo_url';
  static const _keyBio = 'profile_cache_bio';
  static const _keyInterests = 'profile_cache_interests';
  static const _keyAge = 'profile_cache_age';
  static const _keyGender = 'profile_cache_gender';
  static const _keyLanguage = 'profile_cache_language';
  static const _keyCountry = 'profile_cache_country';
  static const _keyCity = 'profile_cache_city';

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
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      interests: (data['interests'] as List?)?.cast<String>() ?? const [],
      age: data['age'] as int?,
      gender: data['gender'] as String?,
      language: data['language'] as String?,
      country: data['country'] as String?,
      city: data['city'] as String?,
      online: data['online'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  Future<UserProfile?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final bio = prefs.getString(_keyBio);
    if (bio == null) return null;
    return UserProfile(
      photoUrl: prefs.getString(_keyPhotoUrl),
      bio: bio,
      interests: prefs.getStringList(_keyInterests) ?? const [],
      age: prefs.getInt(_keyAge),
      gender: prefs.getString(_keyGender),
      language: prefs.getString(_keyLanguage),
      country: prefs.getString(_keyCountry),
      city: prefs.getString(_keyCity),
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
    await prefs.setStringList(_keyInterests, profile.interests);
    if (profile.age != null) await prefs.setInt(_keyAge, profile.age!);
    if (profile.gender != null) await prefs.setString(_keyGender, profile.gender!);
    if (profile.language != null) await prefs.setString(_keyLanguage, profile.language!);
    if (profile.country != null) await prefs.setString(_keyCountry, profile.country!);
    if (profile.city != null) await prefs.setString(_keyCity, profile.city!);
  }

  /// Uploads [localPhotoFile] (if provided) to Firebase Storage and
  /// writes the full profile — including the resulting URL — to
  /// the user's Firestore document. [clearPhoto] removes the photo
  /// entirely instead.
  Future<void> save({
    File? localPhotoFile,
    bool clearPhoto = false,
    required String bio,
    required List<String> interests,
    int? age,
    String? gender,
    String? language,
    String? country,
    String? city,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? photoUrl = state.photoUrl;

    if (clearPhoto) {
      photoUrl = null;
    } else if (localPhotoFile != null) {
      final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
      await ref.putFile(localPhotoFile);
      photoUrl = await ref.getDownloadURL();
    }

    await _firestore.collection('users').doc(uid).set(
      {
        'photoUrl': photoUrl,
        'bio': bio,
        'interests': interests,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (language != null) 'language': language,
        if (country != null) 'country': country,
        if (city != null) 'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // `state` updates automatically via the live Firestore listener above.
  }
}
