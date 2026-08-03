import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

const _localePrefsKey = 'locale';

/// The app's current locale. Always overridden in `main()` with the
/// locale [resolveInitialLocale] already resolved before `runApp` —
/// this default body should never actually run.
final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  throw UnimplementedError('localeProvider must be overridden with the resolved initial locale before use.');
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController(super.initialLocale, this._prefs);

  final SharedPreferences _prefs;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _prefs.setString(_localePrefsKey, locale.languageCode);
  }
}

/// A previously chosen language (Ayarlar → Dil) wins; otherwise falls
/// back to the device locale if the app supports it, and to the first
/// supported locale (Azerbaijani) if it doesn't.
Future<Locale> resolveInitialLocale(SharedPreferences prefs) async {
  final savedCode = prefs.getString(_localePrefsKey);
  final deviceCode = PlatformDispatcher.instance.locale.languageCode;
  final wantedCode = savedCode ?? deviceCode;

  return AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == wantedCode,
    orElse: () => AppLocalizations.supportedLocales.first,
  );
}
