enum PaymentRecordType { purchase, renewal, cancellation, refund }

/// One entry in "Ödəniş tarixçəsi" — populated by the purchase-
/// verification Cloud Function once the VIP subscription flow writes
/// to `users/{uid}/payments` (see the VIP/subscription screen). Empty
/// until that flow exists — this reads a real, always-live collection,
/// it just has nothing in it yet.
class PaymentRecord {
  final String id;
  final PaymentRecordType type;
  final String packageName;
  final double amount;
  final String currency;
  final DateTime createdAt;

  const PaymentRecord({
    required this.id,
    required this.type,
    required this.packageName,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });
}
