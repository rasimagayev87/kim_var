import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart' show TimestampConverter, NullableTimestampConverter;

part 'pinbox_order.freezed.dart';
part 'pinbox_order.g.dart';

/// A buyer's reservation of one [PinBox] — created (with the box's
/// [PinBox.stockRemaining] decremented atomically in the same
/// transaction) exclusively via a Cloud Function callable, never a raw
/// client write (see PinBox Faza 7's checkout flow and this
/// collection's firestore.rules — `allow write: if false`). Per the
/// product's explicit "ləğv edilə bilməz" rule, there is no
/// 'cancelled'/'refunded' status here.
/// [awaitingPayment]/[paymentFailed] bracket the Epoint checkout gate
/// (see `reservePinBoxOrder`/`applyPaymentOutcome` in
/// functions/src/index.ts) — stock is already held the moment an order
/// is created, but it only becomes an actual, redeemable [reserved]
/// ticket once the webhook confirms the charge; a declined/abandoned
/// payment moves it to [paymentFailed] instead and gives the held stock
/// back. Neither is server-default-reachable by name (see the
/// converter below), so a legacy/malformed doc without those two
/// statuses still falls back to [reserved] exactly as before.
enum PinBoxOrderStatus { awaitingPayment, reserved, paymentFailed, completed, expired }

class PinBoxOrderStatusConverter implements JsonConverter<PinBoxOrderStatus, String?> {
  const PinBoxOrderStatusConverter();

  @override
  PinBoxOrderStatus fromJson(String? json) {
    switch (json) {
      case 'awaiting_payment':
        return PinBoxOrderStatus.awaitingPayment;
      case 'payment_failed':
        return PinBoxOrderStatus.paymentFailed;
      case 'completed':
        return PinBoxOrderStatus.completed;
      case 'expired':
        return PinBoxOrderStatus.expired;
      case 'reserved':
      default:
        return PinBoxOrderStatus.reserved;
    }
  }

  @override
  String toJson(PinBoxOrderStatus status) {
    switch (status) {
      case PinBoxOrderStatus.awaitingPayment:
        return 'awaiting_payment';
      case PinBoxOrderStatus.paymentFailed:
        return 'payment_failed';
      case PinBoxOrderStatus.reserved:
        return 'reserved';
      case PinBoxOrderStatus.completed:
        return 'completed';
      case PinBoxOrderStatus.expired:
        return 'expired';
    }
  }
}

@freezed
class PinBoxOrder with _$PinBoxOrder {
  const PinBoxOrder._();

  const factory PinBoxOrder({
    required String id,
    required String pinboxId,
    required String venueId,
    required String buyerId,
    required int quantity,
    required double amountPaid,
    @PinBoxOrderStatusConverter() @Default(PinBoxOrderStatus.reserved) PinBoxOrderStatus status,

    /// Short-lived, signed — regenerated on demand by a Cloud Function
    /// while the order is still 'reserved' and inside the pickup
    /// window, NOT a static value baked in at order-creation time (see
    /// PinBox Faza 8's QR-refresh doc comment for why a static token
    /// would defeat the whole point of the screenshot-resistance
    /// requirement). Null once [status] is no longer 'reserved'.
    String? qrToken,
    @NullableTimestampConverter() DateTime? qrTokenExpiresAt,
    @TimestampConverter() required DateTime createdAt,

    /// Set once, when [status] flips to 'completed' via the venue-side
    /// redemption scan/confirm (PinBox Faza 9). Null otherwise.
    @NullableTimestampConverter() DateTime? redeemedAt,
  }) = _PinBoxOrder;

  factory PinBoxOrder.fromJson(Map<String, dynamic> json) => _$PinBoxOrderFromJson(json);

  factory PinBoxOrder.fromFirestore(String id, Map<String, dynamic> data) {
    return PinBoxOrder.fromJson({...data, 'id': id});
  }

  bool get isReserved => status == PinBoxOrderStatus.reserved;

  bool isBoughtBy(String uid) => buyerId == uid;
}
