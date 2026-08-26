import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../providers/privacy_providers.dart';

/// The *hard* half of "Aktiv cihazlar" remote sign-out (see
/// [DeviceSession]'s doc comment): watches THIS device's own session
/// doc, and if another device deletes it (via "Sign out this device"
/// in the active-devices list), signs this device out locally and
/// returns to the welcome screen. Requires this device to be online
/// and the app running/foregrounded to receive the change — an
/// offline device won't notice until it's next connected.
///
/// Wrap the authenticated app shell in this once, after sign-in (see
/// `HomeScreen`).
class SessionGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  bool _everSawSession = false;

  @override
  void initState() {
    super.initState();
    _startWatching();
    // Best-effort, once per app launch — closes the loop on a pending
    // `verifyBeforeUpdateEmail` confirmation the user may have clicked
    // since the last time this ran (see `AccountRepository
    // .syncEmailFromAuth`'s own doc comment for why this can't happen
    // synchronously at the point the user requests the change).
    ref.read(accountControllerProvider).syncEmailFromAuth();
  }

  Future<void> _startWatching() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final sessionId = await ref.read(deviceSessionRepositoryProvider).currentSessionId();
    if (!mounted) return;

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        _everSawSession = true;
        return;
      }
      // Only react once the doc has been seen existing at least once —
      // otherwise the brief window before the very first
      // touchCurrentSession() write lands would look identical to a
      // revoke and sign the user straight back out.
      if (_everSawSession) _handleRevoked();
    });
  }

  Future<void> _handleRevoked() async {
    await _subscription?.cancel();
    await fb.FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
