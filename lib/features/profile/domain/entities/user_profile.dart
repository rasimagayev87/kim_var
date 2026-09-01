import '../../../../core/utils/age_calculator.dart';
import '../../../../core/utils/presence_utils.dart';

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

  /// Lives on `users/{uid}/private/data`, like [birthDate] — the public
  /// document never carries it. Editable at any time through
  /// `updateProfileDetails`; unlike the handle and the birth date it
  /// carries no cooldown, since a new SIM is an ordinary event and
  /// nothing is gamed by changing it.
  final String? phoneNumber;
  final bool online;
  final DateTime? lastSeen;

  /// The cosmetic profile checkmark badge — true only once the (not yet
  /// built) "Kimlik doğrulama" identity-document flow succeeds. Separate
  /// from [isVerified] on purpose: phone verification unlocks app
  /// actions, but the badge is reserved for real identity verification.
  final bool identityVerified;

  /// Whether this user may create venues/offers — `kBusinessStatusActive`
  /// or `kBusinessStatusNone`, chosen once at onboarding and freely
  /// changeable afterward from Settings. Null only for accounts that
  /// predate this field (pre-migration); read sites should treat that
  /// the same as `kBusinessStatusActive` (see the migration's own
  /// doc comment for why existing users keep their access).
  final String? businessStatus;

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
    this.phoneNumber,
    this.online = false,
    this.lastSeen,
    this.identityVerified = false,
    this.businessStatus,
  });

  /// Always derived from [birthDate] (set once at onboarding) — there is
  /// no separately-editable "age" field, so it can never drift out of
  /// sync with the stored birth date.
  int? get age => birthDate == null ? null : calculateAge(birthDate!);

  /// Mirrors `AppUser.name` — kept as a separate getter (not shared)
  /// because this one reads from the LIVE `profileControllerProvider`
  /// stream, where `AppUser.name` is a one-time snapshot from sign-in
  /// that never updates after a profile edit. Screens showing the
  /// signed-in user's own name should read this, not `AppUser.name`.
  String get name => '$firstName $lastName'.trim();

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
    String? phoneNumber,
    bool? online,
    DateTime? lastSeen,
    String? businessStatus,
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      businessStatus: businessStatus ?? this.businessStatus,
    );
  }

  /// See `isRecentlyOnline`'s doc comment — [online] alone can't be
  /// trusted (a force-quit/crash can leave it stuck `true`), so this
  /// also checks how fresh [lastSeen] is.
  bool get isRecentlyActive =>
      isRecentlyOnline(online: online, lastSeen: lastSeen);

  /// Whether venue/offer creation UI should be shown — true for
  /// `kBusinessStatusActive` AND for a null/absent field (accounts
  /// that predate this field, or the brief window before the
  /// migration backfill reaches them), false only for an explicit
  /// `kBusinessStatusNone`.
  bool get hasBusinessAccess => businessStatus != kBusinessStatusNone;
}

const kGenderOptions = <String>['Kişi', 'Qadın', 'Bildirmək istəmirəm'];

const kBusinessStatusActive = 'active';
const kBusinessStatusNone = 'none';
