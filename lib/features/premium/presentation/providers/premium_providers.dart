import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

/// Real Firestore-backed premium status: `users/{uid}.premium` (bool,
/// default false). No billing/entitlement backend writes this field
/// yet — see [kVipPackages] in `vip_package.dart` for why purchases
/// are stubbed — so today this only flips to `true` if set manually
/// (e.g. via the Firebase console for testing) or once a real
/// RevenueCat webhook / Cloud Function is wired up to write it after
/// a verified purchase. Every screen that gates a feature behind
/// Premium reads through this single provider.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(_premiumStatusProvider).valueOrNull ?? false;
});

final _premiumStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  // isPremiumProvider below is a plain (non-autoDispose) Provider, so
  // once anything reads it, its watch on this provider never lets go —
  // autoDispose here would otherwise never actually fire. Watching
  // authStateProvider is what makes this rebuild on sign-in/sign-out:
  // without it, this provider (and the uid it captured) survives a
  // logout followed by signing into a different account, silently
  // reporting the PREVIOUS account's premium status until a full app
  // restart — same class of bug as chatListControllerProvider's fix.
  ref.watch(authStateProvider);
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()?['premium'] as bool? ?? false);
});
