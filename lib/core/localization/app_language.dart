import 'package:flutter/widgets.dart';

/// One entry in the in-app language picker (Profile → Settings).
///
/// To add a new language: drop an `app_<code>.arb` file in `lib/l10n/`
/// (translating every key from `app_en.arb`) and add its [Locale] here.
/// `flutter gen-l10n` (runs automatically via `generate: true` in
/// pubspec.yaml) regenerates `AppLocalizations` from it — no other code
/// needs to change.
class AppLanguage {
  final Locale locale;
  final String nativeName;

  const AppLanguage(this.locale, this.nativeName);
}

const kSupportedLanguages = <AppLanguage>[
  AppLanguage(Locale('az'), 'Azərbaycan dili'),
  AppLanguage(Locale('tr'), 'Türkçe'),
  AppLanguage(Locale('en'), 'English'),
  AppLanguage(Locale('ru'), 'Русский'),
];

/// Used whenever the device's system language isn't one of
/// [kSupportedLanguages].
const kDefaultLocale = Locale('en');
