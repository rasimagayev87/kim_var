import '../../../../core/utils/age_calculator.dart';

class UserProfile {
  final String? username;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String bio;
  final DateTime? birthDate;
  final String? gender;
  final String? country;
  final String? city;
  final String? email;
  final bool online;
  final DateTime? lastSeen;
  final int heartCount;

  /// The functional "Hesabı təsdiq et" gate — false until the phone-
  /// linking verification flow succeeds. Gates interactive actions via
  /// requireVerified(); no longer drives the profile checkmark badge —
  /// see [identityVerified] for that.
  final bool isVerified;

  /// The cosmetic profile checkmark badge — true only once the (not yet
  /// built) "Kimlik doğrulama" identity-document flow succeeds. Separate
  /// from [isVerified] on purpose: phone verification unlocks app
  /// actions, but the badge is reserved for real identity verification.
  final bool identityVerified;

  const UserProfile({
    this.username,
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.bio = '',
    this.birthDate,
    this.gender,
    this.country,
    this.city,
    this.email,
    this.online = false,
    this.lastSeen,
    this.heartCount = 0,
    this.isVerified = false,
    this.identityVerified = false,
  });

  /// Always derived from [birthDate] (set once at onboarding) — there is
  /// no separately-editable "age" field, so it can never drift out of
  /// sync with the stored birth date.
  int? get age => birthDate == null ? null : calculateAge(birthDate!);

  UserProfile copyWith({
    String? username,
    String? firstName,
    String? lastName,
    String? photoUrl,
    bool clearPhoto = false,
    String? bio,
    DateTime? birthDate,
    String? gender,
    String? country,
    String? city,
    String? email,
    bool? online,
    DateTime? lastSeen,
    int? heartCount,
    bool? isVerified,
  }) {
    return UserProfile(
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      bio: bio ?? this.bio,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      city: city ?? this.city,
      email: email ?? this.email,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      heartCount: heartCount ?? this.heartCount,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

const kGenderOptions = <String>['Kişi', 'Qadın', 'Bildirmək istəmirəm'];
