import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_payment_history_repository.dart';
import '../../data/repositories/firebase_saved_card_repository.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/saved_card.dart';
import '../../domain/repositories/payment_history_repository.dart';
import '../../domain/repositories/saved_card_repository.dart';

final paymentHistoryRepositoryProvider = Provider<PaymentHistoryRepository>((ref) {
  return FirebasePaymentHistoryRepository();
});

final myPaymentHistoryProvider = StreamProvider.autoDispose<List<PaymentRecord>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(paymentHistoryRepositoryProvider).watchHistory(uid);
});

final savedCardRepositoryProvider = Provider<SavedCardRepository>((ref) {
  return FirebaseSavedCardRepository();
});

final savedCardsProvider = StreamProvider.autoDispose<List<SavedCard>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(savedCardRepositoryProvider).watchMyCards(uid);
});
