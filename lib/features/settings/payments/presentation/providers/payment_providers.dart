import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_payment_history_repository.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/saved_card.dart';
import '../../domain/repositories/payment_history_repository.dart';

final paymentHistoryRepositoryProvider = Provider<PaymentHistoryRepository>((ref) {
  return FirebasePaymentHistoryRepository();
});

final myPaymentHistoryProvider = StreamProvider.autoDispose<List<PaymentRecord>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(paymentHistoryRepositoryProvider).watchHistory(uid);
});

/// Stubbed empty — same pattern as `isPremiumProvider`. There's no
/// card-tokenization provider (Stripe et al.) wired up yet, so there's
/// nowhere for real saved cards to come from. Swapping this for a real
/// stream once one exists is a one-line change here with no callers
/// to touch.
final savedCardsProvider = Provider<List<SavedCard>>((ref) => const []);
