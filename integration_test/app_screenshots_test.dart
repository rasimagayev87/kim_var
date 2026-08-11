import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peakpin/core/localization/locale_providers.dart';
import 'package:peakpin/core/widgets/premium_button.dart';
import 'package:peakpin/firebase_options.dart';
import 'package:peakpin/main.dart';

/// Store-screenshot account credentials — never hardcoded. Pass them at
/// run time:
/// `flutter drive --driver=test_driver/integration_test.dart
/// --target=integration_test/app_screenshots_test.dart -d DEVICE_ID
/// --dart-define=SCREENSHOT_USERNAME=... --dart-define=SCREENSHOT_PASSWORD=...`
///
/// Use a dedicated demo account with placeholder content, not a real
/// user's personal profile — these images end up in public app store
/// listings.
const _username = String.fromEnvironment('SCREENSHOT_USERNAME');
const _password = String.fromEnvironment('SCREENSHOT_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store screenshots', (tester) async {
    expect(_username.isNotEmpty && _password.isNotEmpty, isTrue,
        reason: 'Run with --dart-define=SCREENSHOT_USERNAME=... --dart-define=SCREENSHOT_PASSWORD=...');

    // Screenshots saved on-device know their own real platform — unlike
    // the driver script (test_driver/integration_test.dart), which runs
    // on the host desktop OS and can't tell iOS from Android that way.
    final platformDir = Platform.isIOS ? 'ios' : 'android';
    Future<void> shot(String name) => binding.takeScreenshot('$platformDir/$name');

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    final prefs = await SharedPreferences.getInstance();
    final initialLocale = await resolveInitialLocale(prefs);

    await tester.pumpWidget(ProviderScope(
      overrides: [localeProvider.overrideWith((ref) => LocaleController(initialLocale, prefs))],
      child: const PeakPinApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Cold start lands on WelcomeScreen ("Başla"); a stale signed-in
    // session on this device/emulator skips straight to Home — handle
    // both so the script doesn't need a guaranteed-fresh install.
    if (find.text('Başla').evaluate().isNotEmpty) {
      await tester.tap(find.text('Başla'));
      await tester.pumpAndSettle();
    }

    if (find.widgetWithText(PremiumButton, 'Daxil ol').evaluate().isNotEmpty) {
      await shot('01_login');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), _username);
      await tester.enterText(fields.at(1), _password);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PremiumButton, 'Daxil ol'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
    }

    // Discover → İnsanlar (map view) — default view on arrival, tapped
    // explicitly anyway so the screenshot is correct regardless.
    if (find.text('İnsanlar').evaluate().isNotEmpty) {
      await tester.tap(find.text('İnsanlar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    await shot('02_discover_map');

    // Discover → Məkanlar
    await tester.tap(find.text('Məkanlar'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shot('03_discover_venues');

    // Söhbət (chats list)
    await tester.tap(find.text('Söhbət'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shot('04_chats');

    // Profil
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shot('05_profile');

    // Profil → menu → Ayarlar → PeakPin VIP
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('PeakPin VIP'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot('06_vip');
  });
}
