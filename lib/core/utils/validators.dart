import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

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
  /// phone number. Returns a localized error message, or null if valid.
  static String? contact(BuildContext context, String? value) {
    final v = value?.trim() ?? '';
    final loc = AppLocalizations.of(context);
    if (v.isEmpty) return loc.contactRequiredError;
    if (isEmail(v) || isPhone(v)) return null;
    return loc.contactInvalidError;
  }
}
