/// Shared form validators.
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // Accepts international or local formats: optional leading +,
  // 7-15 digits, optional spaces/dashes between them.
  static final _phoneRegex = RegExp(r'^\+?[0-9][0-9\s\-]{6,14}$');

  static bool isEmail(String value) => _emailRegex.hasMatch(value.trim());

  static bool isPhone(String value) => _phoneRegex.hasMatch(value.trim());

  /// Validates a field that accepts either an email address or a
  /// phone number. Returns an error message, or null if valid.
  static String? contact(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-poçt və ya nömrənizi daxil edin';
    if (isEmail(v) || isPhone(v)) return null;
    return 'Düzgün e-poçt və ya nömrə daxil edin';
  }
}
