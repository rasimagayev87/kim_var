/// Which of the 3 sign-in methods created/last-authenticated this
/// account (Apple/Google/E-mail Link — see `AuthRepository`'s own doc
/// comment). Firebase Auth's `providerData` reports Email Link sign-in
/// under the same `password` providerId as the old username+password
/// scheme did, which is why this stays named [email] here rather than
/// literally mirroring that providerId.
enum LoginProvider { email, google, apple }

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final String? gender;
  final LoginProvider loginProvider;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.loginProvider,
    this.username,
    this.email,
    this.phone,
    this.birthDate,
    this.gender,
  });

  String get name => '$firstName $lastName'.trim();

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }
    return years;
  }
}
