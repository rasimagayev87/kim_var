import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firebase_payment_history_repository.dart';
import '../../data/repositories/firebase_saved_card_repository.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/saved_card.dart';
import '../../domain/repositories/payment_history_repository.dart';
import '../../domain/repositories/saved_card_repository.dart';

final paymentHistoryRepositoryProvider = Provider<PaymentHistoryRepository>((
  ref,
) {
  return FirebasePaymentHistoryRepository();
});

final myPaymentHistoryProvider =
    StreamProvider.autoDispose<List<PaymentRecord>>((ref) {
      // Watching authStateProvider forces a rebuild on every real
      // sign-out/sign-in transition — without it, autoDispose's own
      // widget-teardown-triggered disposal can lose the race against a
      // fresh sign-in remounting a subscriber first, resurrecting this
      // provider still bound to the PREVIOUS uid and hitting
      // users/{oldUid}/payments with the new session's auth — a real
      // permission-denied. Same fix pattern as
      // `chatListControllerProvider`/`_premiumStatusProvider`.
      ref.watch(authStateProvider);
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(paymentHistoryRepositoryProvider).watchHistory(uid);
    });

final savedCardRepositoryProvider = Provider<SavedCardRepository>((ref) {
  return FirebaseSavedCardRepository();
});

final savedCardsProvider = StreamProvider.autoDispose<List<SavedCard>>((ref) {
  // See myPaymentHistoryProvider's doc comment above — same fix,
  // same reasoning (this one hits `savedCards where ownerId==oldUid`).
  ref.watch(authStateProvider);
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(savedCardRepositoryProvider).watchMyCards(uid);
});
