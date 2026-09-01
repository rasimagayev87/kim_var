import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/locale_providers.dart';
import 'core/navigation/deep_link_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/premium_background_wrapper.dart';
import 'features/app_config/data/repositories/firebase_app_config_repository.dart';
import 'features/app_config/presentation/providers/app_config_providers.dart';
import 'features/app_config/presentation/widgets/app_config_lifecycle_observer.dart';
import 'features/calls/data/call_push_service.dart';
import 'features/calls/presentation/widgets/call_pip_overlay.dart';
import 'features/location/presentation/providers/location_providers.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/premium/presentation/providers/vip_purchase_listener.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,
  );

  // Incoming-call pushes. Registered BEFORE `runApp` because
  // `onBackgroundMessage` has to be attached while the engine starts —
  // a handler registered later never receives a push that woke the app.
  //
  // Fail-open like every other startup block here: if this throws, calls
  // fall back to the foreground-only Firestore listener, which is what
  // the app did before. It must not be the reason the app cannot open.
  try {
    await CallPushService.initialize();
    await listenToCallkitEvents();
  } catch (_) {
    // Best-effort, see above.
  }

  // Crash reporting must never be the reason the app fails to start —
  // same fail-open shape as the App Check block right below. A failure
  // initializing Crashlytics itself just means crashes go unreported,
  // not that the app can't open.
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Best-effort, see above.
  }

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
    // Bounded: `activate()` itself is a network round-trip on release
    // providers (Play Integrity/DeviceCheck) with no built-in timeout —
    // confirmed on a real device (wireless-debugged iPhone 12 Pro,
    // release build) hanging indefinitely on the launch screen,
    // meaning `runApp()` below never ran. `getToken()`'s own timeout a
    // few lines down only protects the SECOND call, not this one — the
    // exact "must never be the reason the app can't open" failure this
    // whole block claims to prevent.
    await FirebaseAppCheck.instance
        .activate(
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
        )
        .timeout(const Duration(seconds: 5));
    // activate() only registers the token provider — it does NOT mean
    // a token is actually cached yet. The real first fetch is a
    // network round-trip to Apple/Google's attestation servers, and
    // SplashScreen's very first frame already triggers a Firestore
    // read for a returning user (AuthController._restore() →
    // FirebaseAuthRepository._hydrateFromFirestore, users/{uid}.get())
    // with nothing in between to wait for that token. Force-fetching
    // here closes that race window. Bounded by a timeout and
    // swallowed on failure, same fail-open philosophy as activate()
    // itself above — a slow/unreachable attestation service must
    // never be the reason the app can't open.
    await FirebaseAppCheck.instance.getToken().timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  } catch (_) {
    // Best-effort, see above — swallow and continue without App Check.
  }

  final prefs = await SharedPreferences.getInstance();
  final initialLocale = await resolveInitialLocale(prefs);

  // Cache-first: on a returning install this resolves near-instantly
  // from the last-activated Remote Config values (no network wait); the
  // only bounded wait is a genuinely first-ever install with no cache
  // yet — see RemoteConfigDataSource.init()'s own doc comment.
  final appConfigRepository = FirebaseAppConfigRepository();
  await appConfigRepository.init();
  final resolvedAppConfig = appConfigRepository.current(languageCode: initialLocale.languageCode);
  applyRemoteRadiusOptions(resolvedAppConfig.radiusOptionsKm);
  applyRemoteNearbyRefreshSeconds(resolvedAppConfig.nearbyRefreshSeconds);
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => LocaleController(initialLocale, prefs)),
      appConfigRepositoryProvider.overrideWithValue(appConfigRepository),
      installedAppVersionProvider.overrideWithValue(packageInfo.version),
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
      builder: (context, child) => AppConfigLifecycleObserver(
        child: Stack(
          children: [
            if (child != null) PremiumBackgroundWrapper(child: child),
            const CallPipOverlay(),
          ],
        ),
      ),
    );
  }
}
