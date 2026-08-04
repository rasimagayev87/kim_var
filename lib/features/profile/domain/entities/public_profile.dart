import '../../../../core/utils/age_calculator.dart';

/// Another user's profile as seen from the outside (map/card stack,
/// chat header, etc.) — distinct from [UserProfile], which is always
/// the signed-in user's own editable profile.
class PublicProfile {
  final String id;
  final String name;
  final String? username;
  final String? photoUrl;
  final String bio;
  final DateTime? birthDate;
  final String? gender;
  final bool online;
  final DateTime? lastSeen;
  final int starCount;
  final int heartCount;
  final int dislikeCount;

  const PublicProfile({
    required this.id,
    required this.name,
    this.username,
    this.photoUrl,
    this.bio = '',
    this.birthDate,
    this.gender,
    this.online = false,
    this.lastSeen,
    this.starCount = 0,
    this.heartCount = 0,
    this.dislikeCount = 0,
  });

  /// Always derived from [birthDate] — see [UserProfile.age].
  int? get age => birthDate == null ? null : calculateAge(birthDate!);
}
