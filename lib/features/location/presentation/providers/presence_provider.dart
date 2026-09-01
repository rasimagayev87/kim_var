import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/account_status_checker.dart';

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
///
/// This is now the ONLY writer of `online`/`lastSeen` (Düzəliş Prompt 5
/// / RT-24) — `LocationController._writePosition` used to write both
/// fields itself, independent of this controller entirely, which is
/// exactly the kind of second, unaccounted-for write path that made
/// the (now-removed) `showOnlineStatus` toggle an unreliable, false
/// promise in the first place. `LocationController` now only ever
/// touches `lat`/`lng`; presence itself always routes through here.
final presenceControllerProvider = Provider<PresenceController>((ref) {
  final controller = PresenceController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Ticks periodically so any widget rendering `isRecentlyOnline`/
/// `isRecentlyActive` (presence_utils.dart) re-evaluates that
/// wall-clock check even when the peer's Firestore doc hasn't
/// changed — a force-quit or crash on their end never writes again,
/// so nothing would otherwise trigger a rebuild once the staleness
/// window passes, leaving "online" shown forever instead of aging
/// into a last-seen time. `ref.watch` this (the emitted value itself
/// is unused) wherever that staleness check feeds a build method.
/// Comfortably under `kOnlineStalenessThreshold` (90s) so a crossing
/// can't be missed by more than one tick.
final presenceTickProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 20), (i) => i);
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
    _heartbeatTimer ??= Timer.periodic(
      _heartbeatInterval,
      (_) => _writeHeartbeat(),
    );
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
    try {
      await usersDoc.set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Without this, a deleted/banned account's cached ID token would
      // otherwise retry this same failing write every 25s forever (the
      // heartbeat timer, `_heartbeatInterval` above, has no awareness
      // of a previous attempt's outcome) — burning battery/network with
      // no possibility of ever succeeding. `handleWritePermissionDenied`
      // tells a genuine deletion/ban apart from a transient race and,
      // only for the former, forces sign-out AND stops this timer.
      if (await handleWritePermissionDenied(e)) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        _offlineGraceTimer?.cancel();
        _offlineGraceTimer = null;
      }
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _offlineGraceTimer?.cancel();
  }
}
