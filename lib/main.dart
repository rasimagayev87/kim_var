import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/locale_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,
  );

  // Real device attestation (Play Integrity/App Attest) in release
  // builds; the debug provider in dev builds, since a locally
  // `flutter run`-installed app can't pass Play Integrity — its debug
  // token has to be allow-listed in Firebase Console → App Check
  // instead (printed to logcat/Xcode console on first launch). This
  // is what actually backs the phone-verification reCAPTCHA fallback,
  // which had been silently failing without any App Check provider
  // installed (`No AppCheckProvider installed` in logcat).
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  final prefs = await SharedPreferences.getInstance();
  final initialLocale = await resolveInitialLocale(prefs);

  runApp(ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => LocaleController(initialLocale, prefs)),
    ],
    child: const MeevimaApp(),
  ));
}

class MeevimaApp extends ConsumerWidget {
  const MeevimaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meevima',
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashScreen(),
    );
  }
}
