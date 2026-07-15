enum LoginProvider { phone, google, apple }

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
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
