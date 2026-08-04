import '../entities/payment_record.dart';

abstract class PaymentHistoryRepository {
  /// [uid]'s payment history, newest first.
  Stream<List<PaymentRecord>> watchHistory(String uid);
}
