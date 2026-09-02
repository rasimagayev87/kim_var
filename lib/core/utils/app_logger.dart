import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One line at startup proving the release log channel is alive.
///
/// Without it, "no errors in the log" and "the log does not work" look
/// identical — which is exactly the trap that cost a day: every
/// `logError` in the release build was silently going nowhere, and the
/// absence of output read as an absence of problems.
///
/// Carries no user data: a marker, the build mode, and the version
/// string, so a field log also states which build produced it.
void logStartupMarker(String version) {
  debugPrint('PEAKPIN_ALIVE release=$kReleaseMode version=$version');
}

/// Redacts values that must never reach a device log.
///
/// `logcat` is readable over ADB by anyone with physical access to an
/// unlocked phone, and by any app holding READ_LOGS on older/rooted
/// devices. Everything below either identifies a person or grants
/// access, so it is replaced with a typed placeholder rather than
/// dropped — `[email]` still tells whoever reads the log that an email
/// was involved, which is the whole diagnostic value of it.
///
/// Order matters: the longest/most specific patterns run first, so a
/// token is not first half-eaten by the id rule.
String maskSensitive(String input) {
  var out = input;

  // FCM registration tokens and JWT-shaped strings (id tokens, App
  // Check tokens). Both are credentials.
  out = out.replaceAll(RegExp(r'\b[\w-]+:APA91[\w-]{20,}'), '[fcm-token]');
  out = out.replaceAll(RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+'), '[jwt]');

  // Email addresses.
  out = out.replaceAll(RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b'), '[email]');

  // E.164 phone numbers.
  out = out.replaceAll(RegExp(r'\+\d{9,15}\b'), '[phone]');

  // Coordinates: a decimal with 4+ fraction digits is a location, not a
  // count or a price. Deliberately coarse — losing a stray number from
  // a log is cheaper than logging where someone lives.
  out = out.replaceAll(RegExp(r'-?\b\d{1,3}\.\d{4,}\b'), '[coord]');

  // Firebase uids and document ids: 20+ chars of mixed-case alphanumerics.
  // Runs LAST so it cannot swallow the more specific forms above.
  out = out.replaceAll(
    RegExp(r'\b(?=[\w-]*[a-z])(?=[\w-]*[A-Z0-9])[\w-]{20,}\b'),
    '[id]',
  );

  return out;
}

/// An error whose message has been stripped of anything identifying,
/// for sending to Crashlytics.
///
/// Crashlytics reports leave the device and are readable by anyone with
/// console access, so the same rule as `logcat` applies — see
/// [maskSensitive]. Only two things ever reach Crashlytics
/// (`FlutterError.onError` and `PlatformDispatcher.onError`, both in
/// `main.dart`); there are no custom keys and no breadcrumb logs, so
/// the exception message is the entire exposure.
///
/// The ORIGINAL type name is kept in the message on purpose. Crashlytics
/// groups by what it is given, and collapsing every crash into one
/// bucket would trade a privacy problem for a diagnostic one.
/// [maskSensitive] replaces values, not structure, so error codes like
/// `permission-denied` survive and grouping stays meaningful.
class SanitizedError implements Exception {
  final String typeName;
  final String maskedMessage;

  SanitizedError(Object original)
    : typeName = original.runtimeType.toString(),
      maskedMessage = maskSensitive(original.toString());

  @override
  String toString() => '$typeName: $maskedMessage';
}

/// A step that SUCCEEDED, on the release log channel.
///
/// [logError] alone cannot answer the question that matters during a
/// field test: "did this code run at all?" An empty error log reads the
/// same whether the path completed cleanly or was never entered — and
/// on the call flow those two have opposite fixes. This marks the
/// decisive steps so the log shows a route, not just a crash site.
///
/// Kept deliberately sparse: only branch points where the next step
/// depends on which way this one went. Masked like [logError], since it
/// lands in the same `logcat`.
void logTrace(String context, [String detail = '']) {
  if (kReleaseMode) {
    debugPrint(
      'PEAKPIN_TRACE $context${detail.isEmpty ? '' : ': ${maskSensitive(detail)}'}',
    );
  } else {
    developer.log(detail, name: 'peakpin.trace.$context');
  }
}

/// Logs [error] (and [stackTrace] if given) under a consistent tag,
/// instead of ever surfacing it raw to users — Firebase exceptions in
/// particular ("[cloud_firestore/permission-denied] ...") are
/// diagnostic detail, not something a user should ever read.
///
/// Writes through TWO channels because they reach different places:
///
///   * `developer.log` — DevTools/debug console. Invisible in a release
///     build: `dart:developer` output goes to the VM service, and a
///     release APK has none attached.
///   * `debugPrint` — stdout, which the Android runtime forwards to
///     `logcat`. This is the only one that exists in the build we ship
///     and field-test.
///
/// The second channel was missing, and it cost a full day of blind
/// debugging: every `logError` in the release build produced nothing at
/// all, so a background-network failure that broke the entire call flow
/// had to be found in the OS's own `NetdEventListenerService` log
/// instead of ours.
///
/// Only the release channel is masked ([maskSensitive]). The debug
/// console belongs to a developer on their own machine and is more
/// useful unredacted; `logcat` on a shipped device is readable by
/// anyone holding the phone.
void logError(String context, Object error, [StackTrace? stackTrace]) {
  developer.log(
    error.toString(),
    name: 'peakpin.$context',
    error: error,
    stackTrace: stackTrace,
    level: 1000, // SEVERE
  );

  if (kReleaseMode) {
    // Single line, fixed prefix — greppable as `PEAKPIN_ERR`.
    debugPrint('PEAKPIN_ERR $context: ${maskSensitive(error.toString())}');
  }

  logCrashBreadcrumb(context);
}

/// Where [logCrashBreadcrumb] sends its line. `main.dart` points this at
/// `FirebaseCrashlytics.instance.log`; tests point it at a list.
///
/// Injected rather than imported so this file stays testable without a
/// live Firebase app — and so a breadcrumb can never be the thing that
/// throws inside an error handler.
void Function(String line)? crashBreadcrumbSink;

/// Records a breadcrumb on the Crashlytics session.
///
/// A crash report shows the last breadcrumbs before the fatal error, so
/// this is what turns `FirebaseFirestoreHostApi.documentReferenceUpdate`
/// — a stack that stops at the platform channel and names no
/// `package:peakpin/` frame — into an actual source location. The async
/// gap between the Dart call and the plugin reply drops our half of the
/// stack; the breadcrumb survives it.
///
/// [context] is a code path label such as `chat._setActiveChatId`, never
/// a value. It is masked anyway: labels get interpolated over time, and
/// a breadcrumb carrying a uid, e-mail or coordinate would put exactly
/// the data we keep out of `logcat` into a crash report instead.
void logCrashBreadcrumb(String context) {
  final sink = crashBreadcrumbSink;
  if (sink == null) return;
  try {
    sink(maskSensitive(context));
  } catch (_) {
    // A failed breadcrumb must never mask the error it describes.
  }
}

/// True when [error] is a Firestore/Storage permission-denied failure —
/// almost always a stale/signed-out session or (mid-development) security
/// rules that haven't been deployed yet, so it deserves a clearer message
/// than a generic "something went wrong".
bool isPermissionDeniedError(Object error) {
  return error is FirebaseException &&
      errorCodeIs(error.code, 'permission-denied');
}

/// Compares a Firebase error code without letting the device's locale
/// decide what a letter is.
///
/// Measured on an Azerbaijani-locale device:
/// `[firebase_functions/unavaılable]` — with a DOTLESS ı. The native
/// side lowercases the gRPC status name (`UNAVAILABLE`) using the
/// default locale, and in Azerbaijani/Turkish `I` lowercases to `ı`,
/// not `i`. A plain `code == 'unavailable'` therefore never matched,
/// so offline failures were not recognised as offline anywhere in the
/// app and surfaced as generic errors instead.
///
/// Same root as the `firestore.rules` `.lower()` defect fixed earlier
/// the same day, from the opposite direction: there the rules engine
/// was too ASCII, here the device is too Turkish. Both break on exactly
/// the market this app is built for.
///
/// Folds the two Turkish-specific forms back to ASCII before
/// comparing; everything else is already lowercase ASCII in Firebase's
/// code vocabulary.
bool errorCodeIs(String code, String expected) {
  String fold(String v) =>
      v.replaceAll('ı', 'i').replaceAll('İ', 'i').toLowerCase();
  return fold(code) == fold(expected);
}

/// True when [error] is a failure the app is expected to survive, so it
/// must not be recorded as a crash.
///
/// A refused write, a dropped connection and an expired deadline all
/// leave the app running. Counting them as crashes put crash-free users
/// at 72.73% while the top two entries were `permission-denied` writes
/// — the number said the app was falling over when it was not, which
/// hides the failures that matter and can hold up a store release.
///
/// They are still REPORTED, as non-fatals: visible and searchable in
/// Crashlytics, just not counted against stability.
bool isExpectedRuntimeFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is FirebaseException) {
    return errorCodeIs(error.code, 'permission-denied') ||
        errorCodeIs(error.code, 'unavailable') ||
        errorCodeIs(error.code, 'network-request-failed') ||
        errorCodeIs(error.code, 'deadline-exceeded') ||
        errorCodeIs(error.code, 'cancelled');
  }
  return false;
}

/// True when [error] is Firestore's "couldn't reach the backend" failure
/// — the closest thing to a clean offline signal this app gets without a
/// dedicated connectivity package, since Firestore normally serves reads
/// from its local cache instead of throwing when the device is offline.
bool isOfflineError(Object error) {
  return error is FirebaseException &&
      (errorCodeIs(error.code, 'unavailable') ||
          errorCodeIs(error.code, 'network-request-failed'));
}
