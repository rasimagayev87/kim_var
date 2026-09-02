import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/utils/app_logger.dart';
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

/// Routes an uncaught error to Crashlytics — and to `logcat`.
///
/// Two things it fixes.
///
/// FATALITY. Everything used to be recorded `fatal: true`, so a refused
/// Firestore write counted as a crash. Crash-free users sat at 72.73%
/// with the top two "crashes" being `permission-denied` on a write —
/// the app never actually stopped. A metric that counts non-crashes
/// buries the real ones and, on Play Console, can block a release.
/// Network, timeout and permission failures are recorded as
/// NON-FATAL: still reported, still searchable, no longer counted as
/// crashes.
///
/// VISIBILITY. An uncaught async error loses its Dart stack at the
/// platform-channel boundary — the Crashlytics trace for these shows
/// only `messages.pigeon.dart` and nothing of ours, so the calling site
/// is unknowable from the console. Sending it through `logError` puts
/// it in `logcat` with the `PEAKPIN_ERR` prefix, where it can be
/// correlated with what the user was doing on a device.
void _report(Object error, StackTrace? stack) {
  logError('uncaught', error, stack);
  FirebaseCrashlytics.instance.recordError(
    SanitizedError(error),
    stack,
    fatal: !isExpectedRuntimeFailure(error),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Incoming-call pushes. Registered BEFORE `runApp` because
  // `onBackgroundMessage` has to be attached while the engine starts —
  // a handler registered later never receives a push that woke the app.
  //
  // Fail-open like every other startup block here: if this throws, calls
  // fall back to the foreground-only Firestore listener, which is what
  // the app did before. It must not be the reason the app cannot open.
  //
  // ⚠️ A `try/catch` here protects against a THROW, not against a HANG.
  // Anything awaited before `runApp()` that never completes freezes the
  // app on its launch screen with no error and no crash report — see
  // `CallPushService.initialize`'s own doc comment for the instance of
  // that this already caused. Both calls below are non-blocking by
  // construction; keep them that way.
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
    // Sanitised before it leaves the device — see `SanitizedError`.
    //
    // These two handlers are the ONLY paths into Crashlytics (no custom
    // keys, no breadcrumbs, no `setUserIdentifier`), so masking here
    // covers the whole surface. The stack trace itself carries no user
    // data; the exception message can, which is why only that is
    // rewritten.
    FlutterError.onError = (details) =>
        _report(details.exception, details.stack);
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(error, stack);
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
  // App Check moved OFF the startup path.
  //
  // Measured on a Samsung SM-A057F (release, `am start -W`): 2970 ms of
  // a 3125 ms cold start happened before `runApp()`, and this block was
  // the largest single contributor — TWO five-second ceilings, and
  // logcat shows the attestation actually FAILING here
  // (`403 App attestation failed`), so those timeouts were being spent
  // in full on every launch rather than resolving early.
  //
  // Nothing on the first frame needs the token: all 40 callables are
  // deployed with `enforceAppCheck: false`, so no request is rejected
  // without it. Activating after the UI is up returns those seconds and
  // costs nothing — the original comment's concern (App Check must
  // never be the reason the app cannot open) is now structural rather
  // than a matter of picking the right timeout.
  unawaited(
    FirebaseAppCheck.instance
        .activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        )
        .timeout(const Duration(seconds: 5))
        .then(
          (_) => FirebaseAppCheck.instance.getToken().timeout(
            const Duration(seconds: 5),
          ),
        )
        .catchError((Object e, StackTrace st) {
          logError('main.appCheck', e, st);
          return null;
        }),
  );

  final prefs = await SharedPreferences.getInstance();
  final initialLocale = await resolveInitialLocale(prefs);

  // Cache-first: on a returning install this resolves near-instantly
  // from the last-activated Remote Config values (no network wait); the
  // only bounded wait is a genuinely first-ever install with no cache
  // yet — see RemoteConfigDataSource.init()'s own doc comment.
  final appConfigRepository = FirebaseAppConfigRepository();
  await appConfigRepository.init();
  final resolvedAppConfig = appConfigRepository.current(
    languageCode: initialLocale.languageCode,
  );
  applyRemoteRadiusOptions(resolvedAppConfig.radiusOptionsKm);
  applyRemoteNearbyRefreshSeconds(resolvedAppConfig.nearbyRefreshSeconds);
  final packageInfo = await PackageInfo.fromPlatform();
  // Proves the release log channel reaches `logcat` before anything
  // relies on it — see `logStartupMarker`.
  logStartupMarker('${packageInfo.version}+${packageInfo.buildNumber}');

  // Every `logError` now also leaves a masked breadcrumb on the
  // Crashlytics session, so a report whose stack dies at the Firestore
  // platform channel still names the code path that made the call.
  crashBreadcrumbSink = FirebaseCrashlytics.instance.log;

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(
          (ref) => LocaleController(initialLocale, prefs),
        ),
        appConfigRepositoryProvider.overrideWithValue(appConfigRepository),
        installedAppVersionProvider.overrideWithValue(packageInfo.version),
      ],
      child: const PeakPinApp(),
    ),
  );

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
