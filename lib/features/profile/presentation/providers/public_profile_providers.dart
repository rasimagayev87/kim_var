import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Another user's profile as seen from outside (feed post author,
/// comment author, chat-forward target, "Profilə bax") — a read-only
/// projection of `users/{uid}`, distinct from [UserProfile] (which is
/// always the CURRENT user's own editable profile).
class PublicProfile {
  final String uid;
  final String? username;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String bio;
  final String? country;
  final String? city;
  final bool isVerified;
  final bool online;

  const PublicProfile({
    required this.uid,
    this.username,
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.bio = '',
    this.country,
    this.city,
    this.isVerified = false,
    this.online = false,
  });

  String get name => '$firstName $lastName'.trim();
}

/// Live-updating public profile for [uid] — same `users/{uid}` doc
/// [ProfileController] watches for the current user, just read-only
/// and keyed by an arbitrary uid instead of always "me".
final publicProfileProvider = StreamProvider.family<PublicProfile, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PublicProfile(
      uid: uid,
      username: data['username'] as String?,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      country: data['country'] as String?,
      city: data['city'] as String?,
      isVerified: data['isVerified'] as bool? ?? false,
      online: data['online'] as bool? ?? false,
    );
  });
});
