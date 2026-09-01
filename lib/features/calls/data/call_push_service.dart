import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/utils/app_logger.dart';

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
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(callPushBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    // A call push that arrived while the app was terminated and was
    // tapped to open it.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) await _handleMessage(initial);
  }

  static Future<void> _handleMessage(RemoteMessage message) => handleCallPush(message.data);
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
  await handleCallPush(message.data);
}

/// Shared by the foreground listener and the background isolate — the
/// two differ only in which isolate they run in, not in what they do.
Future<void> handleCallPush(Map<String, dynamic> data) async {
  final type = data['type'] as String?;
  final callId = data['callId'] as String?;
  if (callId == null) return;

  try {
    if (type == CallPushService._incoming) {
      await FlutterCallkitIncoming.showCallkitIncoming(
        _incomingCallParams(callId, data),
      );
    } else if (type == CallPushService._cancelled) {
      // Without this the full-screen UI stays up until the OS times it
      // out, and the callee answers a call that ended minutes ago.
      await FlutterCallkitIncoming.endCall(callId);
    }
  } catch (e, st) {
    logError('call_push_service.handleCallPush', e, st);
  }
}

CallKitParams _incomingCallParams(String callId, Map<String, dynamic> data) {
  final isVideo = data['callType'] == 'video';
  return CallKitParams(
    id: callId,
    nameCaller: (data['callerName'] as String?) ?? 'PeakPin',
    appName: 'PeakPin',
    avatar: (data['callerPhoto'] as String?)?.isNotEmpty == true ? data['callerPhoto'] as String : null,
    type: isVideo ? 1 : 0,
    // The server's FCM TTL is 45s; the UI stops ringing on the same
    // budget so a push that only just made it does not ring alone
    // after the caller has given up.
    duration: 45000,
    textAccept: 'Cavab ver',
    textDecline: 'Rədd et',
    extra: <String, dynamic>{'callId': callId, 'callerId': data['callerId'] ?? ''},
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
Future<void> listenToCallkitEvents() async {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    final callId = (event.body is Map ? (event.body as Map)['id'] : null) as String?;
    if (callId == null) return;

    try {
      switch (event.event) {
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          await FirebaseFirestore.instance.collection('calls').doc(callId).update({
            'status': 'declined',
          });
        case Event.actionCallAccept:
          // Accepting only marks the document; the WebRTC answer is
          // built by `ActiveCallController` once the app is in the
          // foreground and can open a microphone. Marking it here is
          // what stops the caller's ringback immediately.
          if (fb.FirebaseAuth.instance.currentUser != null) {
            await FirebaseFirestore.instance.collection('calls').doc(callId).update({
              'status': 'accepted',
            });
          }
        default:
          break;
      }
    } catch (e, st) {
      logError('call_push_service.onEvent', e, st);
    }
  });
}
