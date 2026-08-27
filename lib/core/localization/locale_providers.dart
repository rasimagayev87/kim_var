import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

const _localePrefsKey = 'app_locale_code';

/// Reads the persisted locale, or falls back to [kDefaultLocale]
/// (English) — deliberately NOT the device's system language, so a
/// fresh install always opens in English regardless of the device's
/// own locale; the language picker (Welcome screen or Settings) is
/// what actually sets it from there, and that choice is what gets
/// persisted and reloaded on the next launch. Called once in `main()`,
/// before `runApp`, so the very first frame already renders in the
/// right language instead of flashing a default and then switching.
Future<Locale> resolveInitialLocale(SharedPreferences prefs) async {
  final savedCode = prefs.getString(_localePrefsKey);
  if (savedCode != null) {
    for (final language in kSupportedLanguages) {
      if (language.locale.languageCode == savedCode) return language.locale;
    }
  }
  return kDefaultLocale;
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
