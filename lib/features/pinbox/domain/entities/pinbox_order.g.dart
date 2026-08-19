// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pinbox_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PinBoxOrderImpl _$$PinBoxOrderImplFromJson(
  Map<String, dynamic> json,
) => _$PinBoxOrderImpl(
  id: json['id'] as String,
  pinboxId: json['pinboxId'] as String,
  venueId: json['venueId'] as String,
  buyerId: json['buyerId'] as String,
  quantity: (json['quantity'] as num).toInt(),
  amountPaid: (json['amountPaid'] as num).toDouble(),
  status: json['status'] == null
      ? PinBoxOrderStatus.reserved
      : const PinBoxOrderStatusConverter().fromJson(json['status'] as String?),
  qrToken: json['qrToken'] as String?,
  qrTokenExpiresAt: const NullableTimestampConverter().fromJson(
    json['qrTokenExpiresAt'],
  ),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  redeemedAt: const NullableTimestampConverter().fromJson(json['redeemedAt']),
);

Map<String, dynamic> _$$PinBoxOrderImplToJson(
  _$PinBoxOrderImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'pinboxId': instance.pinboxId,
  'venueId': instance.venueId,
  'buyerId': instance.buyerId,
  'quantity': instance.quantity,
  'amountPaid': instance.amountPaid,
  'status': const PinBoxOrderStatusConverter().toJson(instance.status),
  'qrToken': instance.qrToken,
  'qrTokenExpiresAt': const NullableTimestampConverter().toJson(
    instance.qrTokenExpiresAt,
  ),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'redeemedAt': const NullableTimestampConverter().toJson(instance.redeemedAt),
};
