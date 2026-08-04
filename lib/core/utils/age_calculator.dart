/// Computes a whole-years-old age from a birth date, matching the
/// standard "hasn't had this year's birthday yet" rule rather than a
/// naive year subtraction.
int calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final hadBirthdayThisYear =
      now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}
