import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

/// Real Firestore-backed premium status: `users/{uid}.premium` (bool,
/// default false). Written either by the admin panel's manual "VIP et"
/// grant, or by a verified Apple/Google IAP purchase
/// (`verifyInAppPurchase`/`appStoreServerNotifications`/
/// `googlePlayRtdn`, functions/src/index.ts) — never by the client
/// itself (see firestore.rules' lock on this field). Every screen that
/// gates a feature behind Premium reads through this single provider.
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
