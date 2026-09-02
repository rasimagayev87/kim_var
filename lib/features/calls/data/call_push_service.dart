import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/incoming_call_filter.dart';
import '../../../firebase_options.dart';

/// Turns an incoming-call push into a ringing phone.
///
/// ── The gap this closes ────────────────────────────────────────────
///
/// Until now the ONLY thing that noticed an incoming call was a
/// Firestore snapshot listener attached by `HomeScreen`
/// (`incomingCallProvider`). That listener exists solely while the app
/// is in the foreground, so a backgrounded or closed app was never told
/// anything at all: the caller heard its own local ringback
/// (`ActiveCallController._ringbackPlayer`, which is driven by the
/// caller's own Firestore write and says nothing about whether the
/// callee was reached), the callee's phone stayed dark, and the first
/// sign of the call was the "missed call" CHAT MESSAGE that the
/// caller's device writes after the call has already ended.
///
/// The server now sends a `data`-only, high-priority push
/// (`onCallCreated`). This is the client half: the handler that turns
/// it into a full-screen incoming-call UI even when the app is not
/// running.
///
/// ── Why `data`-only matters ────────────────────────────────────────
///
/// A push carrying a `notification` block is rendered by the Android
/// system and does NOT start the app's Dart isolate. It would produce
/// a silent tray entry and nothing else — which is very close to the
/// original symptom. Only a data message reaches
/// [callPushBackgroundHandler].
class CallPushService {
  CallPushService._();

  /// `type` values the server sends — see `onCallCreated` /
  /// `onCallUpdated` in functions/src/index.ts.
  static const String _incoming = 'incoming_call';
  static const String _cancelled = 'call_cancelled';

  /// Wired once at startup, before `runApp`.
  ///
  /// ── NOTHING HERE MAY BLOCK ─────────────────────────────────────
  ///
  /// This runs before `runApp()`, so anything awaited here that does
  /// not complete freezes the app on its launch screen with no error
  /// and no crash report. A `try/catch` around the call site does NOT
  /// protect against that — it catches throws, not hangs.
  ///
  /// That is exactly what happened: this method used to
  /// `await FirebaseMessaging.instance.getInitialMessage()`. On iOS
  /// that call waits for APNs registration, and on a build whose
  /// provisioning profile carries no push entitlement (a personal-team
  /// signature, which is every local device build until the Apple
  /// Developer membership is active) registration never completes. The
  /// app opened to a blank screen and stayed there.
  ///
  /// So: the two registrations below are synchronous and must stay
  /// ahead of `runApp`, and the terminated-launch lookup is
  /// deliberately NOT awaited.
  /// Guards against double registration.
  ///
  /// `main()` can run more than once in the SAME process: answering
  /// from the OS call screen relaunches `MainActivity`, and the engine
  /// re-runs the entrypoint without tearing down what the previous run
  /// registered. Observed on device as every trace line appearing
  /// twice — two `onMessage` listeners meant each push was handled
  /// twice, so `deliveredAt` was written twice and the CallKit UI was
  /// raised twice for one call.
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(callPushBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // A call push that arrived while the app was terminated and was
    // tapped to open it. Fire-and-forget WITH a timeout: the app must
    // reach `runApp` whether or not this ever answers, and a call from
    // before the app was even running is not worth a second of launch.
    unawaited(
      FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5))
          .then((initial) {
            if (initial != null) return _handleMessage(initial);
            return null;
          })
          .catchError((Object e, StackTrace st) {
            logError('call_push_service.getInitialMessage', e, st);
            return null;
          }),
    );
  }

  static Future<void> _handleMessage(RemoteMessage message) =>
      handleCallPush(message.data, showNativeUi: false);
}

/// Background isolate entry point.
///
/// `@pragma('vm:entry-point')` is load-bearing: without it the AOT
/// compiler drops this function as unreachable (nothing in Dart calls
/// it — the engine does, by name) and background pushes silently do
/// nothing in release builds while working perfectly in debug.
///
/// Runs in its OWN isolate with no access to the app's providers, so it
/// talks to `FlutterCallkitIncoming` directly rather than through any
/// of the app's state.
@pragma('vm:entry-point')
Future<void> callPushBackgroundHandler(RemoteMessage message) async {
  // `Firebase.initializeApp()` must be called HERE, not just in
  // `main()`. A background isolate starts with nothing: `main()` never
  // ran in it, so every Firebase plugin is uninitialised and
  // `FirebaseFirestore.instance` cannot reach the backend.
  //
  // This is what broke the caller's "Zəng çalınır" label. The CallKit
  // screen appeared normally — that is a platform channel and needs no
  // Firebase — but the `deliveredAt` write inside `handleCallPush`
  // failed, and its failure was invisible twice over: swallowed by
  // `_markDelivered`'s own catch, and detached from any awaiting caller
  // by `unawaited`. The caller therefore kept showing "Zəng gedir"
  // while the callee's phone was audibly ringing.
  //
  // Idempotent: calling it again in an isolate that already has the
  // default app is a no-op, so the foreground path is unaffected.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // A duplicate-app error is harmless and expected on some launch
    // orders; anything else still must not stop the phone ringing, so
    // the CallKit UI below runs either way.
    logError('call_push_service.backgroundInit', e, st);
  }
  logTrace('bgHandler.entered');
  await handleCallPush(message.data, showNativeUi: true);
}

/// Shared by the foreground listener and the background isolate — the
/// two differ only in which isolate they run in, not in what they do.
/// [showNativeUi] decides whether the OS call screen is raised.
///
/// It must be false while the app is in the FOREGROUND. Both surfaces
/// react to the same call: this push raises the CallKit screen, and
/// `incomingCallProvider` independently pushes `IncomingCallScreen` the
/// moment the document appears. With both enabled the callee saw TWO
/// incoming-call UIs stacked for one call and had to answer both — the
/// OS one and the in-app one.
///
/// The in-app screen wins in the foreground: it is the surface that
/// calls `acceptCall()` directly, and it matches what the user is
/// already looking at. CallKit stays for the background and killed
/// cases, where no Flutter UI exists to show anything.
///
/// `deliveredAt` is marked either way — the caller's "Zəng çalınır"
/// depends on the callee's device having surfaced the call, not on
/// which surface did it.
Future<void> handleCallPush(
  Map<String, dynamic> data, {
  required bool showNativeUi,
}) async {
  final type = data['type'] as String?;
  final callId = data['callId'] as String?;
  if (callId == null) return;

  try {
    if (type == CallPushService._incoming) {
      if (showNativeUi) {
        await FlutterCallkitIncoming.showCallkitIncoming(
          _incomingCallParams(callId, data),
        );
        logTrace('handleCallPush.callkitShown', callId);
      } else {
        logTrace('handleCallPush.foregroundSkippedNativeUi', callId);
      }
      // Marked AFTER the UI is up, not on receipt of the push: the
      // caller's "Zəng çalınır" must mean a phone is actually ringing,
      // not that a message arrived somewhere. One extra write per call,
      // and `firestore.rules` lets only the callee make it.
      unawaited(_markDelivered(callId));
    } else if (type == CallPushService._cancelled) {
      // Without this the full-screen UI stays up until the OS times it
      // out, and the callee answers a call that ended minutes ago.
      await FlutterCallkitIncoming.endCall(callId);
    }
  } catch (e, st) {
    logError('call_push_service.handleCallPush', e, st);
  }
}

/// Best-effort: a failure here costs the caller a more precise label,
/// nothing more, so it must never stop the phone ringing.
///
/// `firestore.rules` only lets the CALLEE write this field
/// (`request.auth.uid == resource.data.receiverId`), so the write needs
/// a restored auth session. In a freshly-spawned background isolate
/// that session is read back from disk during/after
/// `Firebase.initializeApp()` and is not always present on the very
/// next line — `currentUser` can still be null for a moment. Reading it
/// once and giving up would fail exactly in the case this function
/// exists for: a call arriving while the app is not running.
Future<void> _markDelivered(String callId) async {
  try {
    final auth = fb.FirebaseAuth.instance;
    if (auth.currentUser == null) {
      // First non-null emission, or nothing within the timeout. The
      // ring itself is already up, so a short wait costs the user
      // nothing.
      await auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5));
    }
    if (auth.currentUser == null) {
      logError(
        'call_push_service.markDelivered',
        'no auth session in isolate',
        StackTrace.current,
      );
      return;
    }
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'deliveredAt': FieldValue.serverTimestamp(),
    });
    logTrace('markDelivered.ok', callId);
  } catch (e, st) {
    logError('call_push_service.markDelivered', e, st);
  }
}

CallKitParams _incomingCallParams(String callId, Map<String, dynamic> data) {
  final isVideo = data['callType'] == 'video';
  return CallKitParams(
    id: callId,
    nameCaller: (data['callerName'] as String?) ?? 'PeakPin',
    appName: 'PeakPin',
    avatar: (data['callerPhoto'] as String?)?.isNotEmpty == true
        ? data['callerPhoto'] as String
        : null,
    type: isVideo ? 1 : 0,
    // The server's FCM TTL is 45s; the UI stops ringing on the same
    // budget so a push that only just made it does not ring alone
    // after the caller has given up.
    duration: 45000,
    textAccept: 'Cavab ver',
    textDecline: 'Rədd et',
    extra: <String, dynamic>{
      'callId': callId,
      'callerId': data['callerId'] ?? '',
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0B1330',
      actionColor: '#12D6E8',
      // The whole point: raises the call UI over the lock screen
      // instead of leaving a tray entry. Requires
      // USE_FULL_SCREEN_INTENT in AndroidManifest.
      isShowFullLockedScreen: true,
    ),
    ios: const IOSParams(
      // Inert until a PushKit VoIP certificate exists — see
      // docs/CALLS.md. The configuration is correct now so that
      // enabling it later is a certificate upload, not a code change.
      supportsVideo: true,
      supportsHolding: false,
      supportsGrouping: false,
      supportsUngrouping: false,
    ),
  );
}

/// Declining from the OS call UI has to reach Firestore, because the
/// app may never be opened — the caller would otherwise ring until it
/// timed out.
///
/// Listens to the plugin's own event stream; wired at startup alongside
/// [CallPushService.initialize].
/// Recovers an answer that was given while the app was NOT running.
///
/// [listenToCallkitEvents] only works if a Dart isolate is alive to
/// receive the event. When the app is fully killed — the ordinary case
/// for an incoming call — the user taps Accept on the OS screen, the
/// plugin launches the app, and the accept event can be gone before
/// `main()` has attached a listener. The call document then stays
/// `ringing`, and the callee is asked to accept a call they already
/// accepted.
///
/// The plugin's native broadcast receiver does not depend on Dart: on
/// `ACTION_CALL_ACCEPT` it writes the call into its own
/// `ACTIVE_CALLS` store with `isAccepted: true` (SharedPreferences on
/// Android). Reading that at startup tells us what the OS knows and the
/// isolate missed.
///
/// Writing `accepted` here is all this does; `HomeScreen`'s
/// `incomingCallProvider` listener then finds the document exactly as
/// it would for any other OS-accepted call and runs the WebRTC setup.
/// Deliberately NOT navigating from here — one navigation path for both
/// cases, so a cold start cannot behave differently from a warm one.
Future<void> recoverAcceptedCallsAfterColdStart() async {
  try {
    if (fb.FirebaseAuth.instance.currentUser == null) return;
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active is! List) return;
    for (final entry in active) {
      if (entry is! Map) continue;
      if (entry['isAccepted'] != true) continue;
      final callId = entry['id'] as String?;
      if (callId == null) continue;

      final ref = FirebaseFirestore.instance.collection('calls').doc(callId);
      final snap = await ref.get();
      final data = snap.data();
      // Only a call still waiting for this device. Anything already
      // answered, declined or ended is none of our business, and
      // `answer != null` means the setup already happened.
      if (data == null) continue;
      if (data['status'] != 'ringing') continue;
      if (data['answer'] != null) continue;
      if (data['receiverId'] != fb.FirebaseAuth.instance.currentUser?.uid)
        continue;

      // Same staleness bound the UI applies, for the same reason and so
      // the two cannot disagree. The plugin's store only drops a call on
      // end/decline/timeout, so an app killed mid-call can leave an
      // entry behind indefinitely; without this it would mark a
      // day-old document `accepted` that nothing would then open.
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null &&
          DateTime.now().difference(createdAt) > kIncomingCallMaxAge) {
        // Clear it so the next cold start does not look at it again.
        unawaited(
          FlutterCallkitIncoming.endCall(callId).catchError((Object e) {
            logError('calls.coldStartRecovery.endCall', e);
          }),
        );
        continue;
      }

      logTrace('coldStartRecovery.marked', callId);
      await ref.update({'status': 'accepted'});
    }
  } catch (e, st) {
    // A failure here costs the user one extra tap on the in-app accept
    // screen, which is still shown because the document stays
    // `ringing`. It must never block startup.
    logError('call_push_service.recoverAcceptedCalls', e, st);
  }
}

bool _callkitListenerAttached = false;

Future<void> listenToCallkitEvents() async {
  // Same re-entrancy as `CallPushService.initialize` — see its note.
  if (_callkitListenerAttached) return;
  _callkitListenerAttached = true;
  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    final callId =
        (event.body is Map ? (event.body as Map)['id'] : null) as String?;
    if (callId == null) return;

    try {
      switch (event.event) {
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .update({'status': 'declined'});
        case Event.actionCallAccept:
          // Accepting only marks the document; the WebRTC answer is
          // built by `ActiveCallController` once the app is in the
          // foreground and can open a microphone. Marking it here is
          // what stops the caller's ringback immediately.
          logTrace('callkitEvent.accept', callId);
          if (fb.FirebaseAuth.instance.currentUser == null) {
            logError(
              'call_push_service.accept',
              'no auth session',
              StackTrace.current,
            );
          } else {
            await FirebaseFirestore.instance
                .collection('calls')
                .doc(callId)
                .update({'status': 'accepted'});
            logTrace('callkitEvent.accept.written', callId);
          }
        default:
          break;
      }
    } catch (e, st) {
      logError('call_push_service.onEvent', e, st);
    }
  });
}
