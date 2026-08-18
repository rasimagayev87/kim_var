import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/public_profile.dart';

/// Live view of any user's public profile by uid — used wherever the
/// app shows someone ELSE's profile (discover card stack, chat header),
/// as opposed to `profileControllerProvider`, which is always the
/// signed-in user's own.
final publicProfileProvider = StreamProvider.family<PublicProfile?, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return null;

    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';

    return PublicProfile(
      id: uid,
      name: '$firstName $lastName'.trim(),
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      gender: data['gender'] as String?,
      online: data['online'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      starCount: (data['starCount'] as num?)?.toInt() ?? 0,
      heartCount: (data['heartCount'] as num?)?.toInt() ?? 0,
      dislikeCount: (data['dislikeCount'] as num?)?.toInt() ?? 0,
      identityVerified: data['identityVerified'] as bool? ?? false,
      premium: data['premium'] as bool? ?? false,
    );
  });
});
