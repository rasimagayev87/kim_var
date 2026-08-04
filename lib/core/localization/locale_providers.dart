import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

const _localePrefsKey = 'app_locale_code';

/// Maps the device's system language to one of [kSupportedLanguages],
/// falling back to [kDefaultLocale] (English) for anything else.
Locale detectSystemLocale() {
  final systemCode = PlatformDispatcher.instance.locale.languageCode;
  for (final language in kSupportedLanguages) {
    if (language.locale.languageCode == systemCode) return language.locale;
  }
  return kDefaultLocale;
}

/// Reads the persisted locale, or falls back to (and persists) the
/// detected system locale. Called once in `main()`, before `runApp`, so
/// the very first frame already renders in the right language instead of
/// flashing a default and then switching.
Future<Locale> resolveInitialLocale(SharedPreferences prefs) async {
  final savedCode = prefs.getString(_localePrefsKey);
  if (savedCode != null) {
    for (final language in kSupportedLanguages) {
      if (language.locale.languageCode == savedCode) return language.locale;
    }
  }

  final detected = detectSystemLocale();
  await prefs.setString(_localePrefsKey, detected.languageCode);
  return detected;
}

/// Holds the app's current locale and persists changes to
/// SharedPreferences so the same language loads on the next launch.
class LocaleController extends StateNotifier<Locale> {
  LocaleController(super.initialLocale, this._prefs);

  final SharedPreferences _prefs;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _prefs.setString(_localePrefsKey, locale.languageCode);
  }
}

/// Overridden in `main()` with the already-resolved initial locale and a
/// ready [SharedPreferences] instance — see [resolveInitialLocale].
final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  throw UnimplementedError('localeProvider must be overridden in main()');
});
