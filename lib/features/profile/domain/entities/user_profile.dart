class UserProfile {
  final String? photoUrl;
  final String bio;
  final List<String> interests;
  final int? age;
  final String? gender;
  final String? language;
  final String? country;
  final String? city;
  final bool online;
  final DateTime? lastSeen;

  const UserProfile({
    this.photoUrl,
    this.bio = '',
    this.interests = const [],
    this.age,
    this.gender,
    this.language,
    this.country,
    this.city,
    this.online = false,
    this.lastSeen,
  });

  /// Matches the MVP spec: photo, bio, at least one interest, and
  /// the core demographic fields all filled in.
  bool get isComplete =>
      photoUrl != null &&
      bio.isNotEmpty &&
      interests.isNotEmpty &&
      age != null &&
      gender != null &&
      language != null &&
      country != null &&
      city != null &&
      city!.isNotEmpty;

  UserProfile copyWith({
    String? photoUrl,
    bool clearPhoto = false,
    String? bio,
    List<String>? interests,
    int? age,
    String? gender,
    String? language,
    String? country,
    String? city,
    bool? online,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      country: country ?? this.country,
      city: city ?? this.city,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// The fixed catalogue of interests users can pick from, matching
/// the project's product spec.
const kAvailableInterests = <String>[
  'Futbol',
  'Səyahət',
  'Kitab',
  'Kino',
  'Qəhvə',
  'Startuplar',
  'Fitness',
  'Motosiklet',
  'Fotoqrafiya',
  'Süni intellekt',
];

const kGenderOptions = <String>['Kişi', 'Qadın', 'Bildirmək istəmirəm'];

const kLanguageOptions = <String>[
  'Azərbaycan',
  'Türk',
  'İngilis',
  'Rus',
  'Ərəb',
];
