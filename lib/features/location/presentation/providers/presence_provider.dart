import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the signed-in user's `online` flag and `lastSeen` timestamp
/// in Firestore up to date — a heartbeat while foregrounded, and a
/// grace-period-delayed offline write when backgrounded, rather than
/// a naive instant flip either way. Two things make the naive version
/// (write `online: true`/`false` directly on each lifecycle callback,
/// nothing else) unreliable, which is why this exists:
///
/// 1. A force-quit, crash, or the OS silently killing a backgrounded
///    process never fires `paused`/`detached` cleanly — `online` can
///    get stuck `true` forever with no write ever correcting it. The
///    heartbeat here doesn't fix that by itself, but combined with
///    `isRecentlyOnline`'s staleness check on every *read* site
///    (`core/utils/presence_utils.dart`), a stale `online: true`
///    self-heals once `lastSeen` falls outside the staleness window —
///    no single write path needs to be perfectly reliable.
/// 2. Backgrounding briefly (checking a notification, switching apps
///    for a few seconds) shouldn't flicker presence off and back on
///    for everyone watching this user — see [scheduleOffline]'s grace
///    period.
final presenceControllerProvider = Provider<PresenceController>((ref) {
  final controller = PresenceController();
  ref.onDispose(controller.dispose);
  return controller;
});

class PresenceController {
  PresenceController({FirebaseFirestore? firestore, fb.FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  static const _heartbeatInterval = Duration(seconds: 25);
  // "maksimum 1 dəqiqəlik grace period" — kOnlineStalenessThreshold
  // (presence_utils.dart) is set comfortably past this so a reader
  // never treats someone as offline before this grace period itself
  // would have.
  static const _backgroundGracePeriod = Duration(seconds: 60);

  Timer? _heartbeatTimer;
  Timer? _offlineGraceTimer;

  /// App resumed to the foreground (or first launched). Cancels any
  /// pending grace-period offline write, writes online immediately,
  /// and (re)starts the heartbeat.
  Future<void> setOnline() async {
    _offlineGraceTimer?.cancel();
    _offlineGraceTimer = null;
    await _writeHeartbeat();
    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) => _writeHeartbeat());
  }

  /// App backgrounded (`paused`/`detached`). Doesn't write offline
  /// immediately — starts the grace-period timer instead, cancelled
  /// by a subsequent [setOnline] if the app comes back before it
  /// fires.
  void scheduleOffline() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _offlineGraceTimer?.cancel();
    _offlineGraceTimer = Timer(_backgroundGracePeriod, _writeOffline);
  }

  /// Immediate offline write, no grace period — explicit logout, not
  /// backgrounding.
  Future<void> setOfflineNow() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _offlineGraceTimer?.cancel();
    _offlineGraceTimer = null;
    await _writeOffline();
  }

  Future<void> _writeHeartbeat() => _write(online: true);

  Future<void> _writeOffline() => _write(online: false);

  Future<void> _write({required bool online}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final usersDoc = _firestore.collection('users').doc(uid);
    if (online) {
      // A user with "Onlayn olduğumu göstər" off never gets written
      // as online at all — the only way this setting reliably governs
      // every place `online`/`lastSeen` get read is to never let them
      // become true/fresh in the first place, rather than teaching
      // every reader about this one toggle. Going offline (below)
      // always writes through regardless — that never leaks anything.
      final showOnlineStatus = await _showOnlineStatus(usersDoc);
      if (!showOnlineStatus) return;
    }
    await usersDoc.set({
      'online': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> _showOnlineStatus(DocumentReference<Map<String, dynamic>> usersDoc) async {
    try {
      final doc = await usersDoc.get();
      return doc.data()?['showOnlineStatus'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _offlineGraceTimer?.cancel();
  }
}
