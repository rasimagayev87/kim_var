// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pinbox.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PinBoxImpl _$$PinBoxImplFromJson(Map<String, dynamic> json) => _$PinBoxImpl(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  venueId: json['venueId'] as String,
  venueName: json['venueName'] as String,
  venuePhotoUrl: json['venuePhotoUrl'] as String?,
  category: const VenueCategoryConverter().fromJson(
    json['category'] as String?,
  ),
  title: json['title'] as String,
  description: json['description'] as String,
  imageUrl: json['imageUrl'] as String?,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  address: json['address'] as String,
  country: json['country'] as String?,
  originalPrice: (json['originalPrice'] as num).toDouble(),
  pinboxPrice: (json['pinboxPrice'] as num).toDouble(),
  stockTotal: (json['stockTotal'] as num).toInt(),
  stockRemaining: (json['stockRemaining'] as num).toInt(),
  pickupWindowStart: const TimestampConverter().fromJson(
    json['pickupWindowStart'],
  ),
  pickupWindowEnd: const TimestampConverter().fromJson(json['pickupWindowEnd']),
  status: json['status'] as String? ?? 'pending',
  reviewNote: json['reviewNote'] as String?,
  reviewedBy: json['reviewedBy'] as String?,
  reviewedAt: const NullableTimestampConverter().fromJson(json['reviewedAt']),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$$PinBoxImplToJson(
  _$PinBoxImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'venueId': instance.venueId,
  'venueName': instance.venueName,
  'venuePhotoUrl': instance.venuePhotoUrl,
  'category': const VenueCategoryConverter().toJson(instance.category),
  'title': instance.title,
  'description': instance.description,
  'imageUrl': instance.imageUrl,
  'lat': instance.lat,
  'lng': instance.lng,
  'address': instance.address,
  'country': instance.country,
  'originalPrice': instance.originalPrice,
  'pinboxPrice': instance.pinboxPrice,
  'stockTotal': instance.stockTotal,
  'stockRemaining': instance.stockRemaining,
  'pickupWindowStart': const TimestampConverter().toJson(
    instance.pickupWindowStart,
  ),
  'pickupWindowEnd': const TimestampConverter().toJson(
    instance.pickupWindowEnd,
  ),
  'status': instance.status,
  'reviewNote': instance.reviewNote,
  'reviewedBy': instance.reviewedBy,
  'reviewedAt': const NullableTimestampConverter().toJson(instance.reviewedAt),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
};
