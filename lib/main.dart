import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/locale_providers.dart';
import 'core/navigation/deep_link_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/premium_background_wrapper.dart';
import 'features/calls/presentation/widgets/call_pip_overlay.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/premium/presentation/providers/vip_purchase_listener.dart';
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
  //
  // Wrapped: a sideloaded/ad-hoc release APK (not installed via Play
  // Store) can make the Play Integrity provider throw a raw
  // PlatformException *during activation itself* — before any network
  // round-trip, before enforcement even matters — which would
  // otherwise crash before runApp() ever runs (confirmed on a real
  // device: the app never got past its native launch splash). App
  // Check activation must never be the reason the app can't open; a
  // user stuck on this path just gets rejected by server-side
  // enforcement on individual requests instead of never seeing the UI.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // Was AppleProvider.appAttest — real devices (confirmed: Google
      // Sign-In itself succeeding, Gmail even sending its own "new
      // sign-in" notification) were getting "Firebase App Check token is
      // invalid" back from Identity Toolkit even with server-side
      // enforcement OFF, meaning the SDK was generating a broken
      // attestation and still attaching it. DeviceCheck is the older,
      // simpler Apple attestation API — no per-install key generation to
      // go stale/mismatch the way App Attest's can.
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (_) {
    // Best-effort, see above — swallow and continue without App Check.
  }

  final prefs = await SharedPreferences.getInstance();
  final initialLocale = await resolveInitialLocale(prefs);

  runApp(ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => LocaleController(initialLocale, prefs)),
    ],
    child: const PeakPinApp(),
  ));

  startDeepLinkListener();
  startVipPurchaseListener();

  await FlutterBranchSdk.init(enableLogging: kDebugMode);
  startBranchDeepLinkListener();
}

class PeakPinApp extends ConsumerWidget {
  const PeakPinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PeakPin',
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashScreen(),
      // Floats the minimized-call PiP bubble above whatever route is
      // currently showing, regardless of navigation depth — it has to
      // live here, above the Navigator, rather than inside any one
      // screen, since minimizing a call is specifically meant to let
      // the user navigate freely underneath it.
      builder: (context, child) => Stack(
        children: [
          if (child != null) PremiumBackgroundWrapper(child: child),
          const CallPipOverlay(),
        ],
      ),
    );
  }
}
