// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OfferImpl _$$OfferImplFromJson(Map<String, dynamic> json) => _$OfferImpl(
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
  offerType: const OfferTypeConverter().fromJson(json['offerType'] as String?),
  discountValue: (json['discountValue'] as num?)?.toDouble(),
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  address: json['address'] as String,
  country: json['country'] as String?,
  startDate: const TimestampConverter().fromJson(json['startDate']),
  endDate: const TimestampConverter().fromJson(json['endDate']),
  imageUrl: json['imageUrl'] as String?,
  terms: json['terms'] as String?,
  status: json['status'] as String? ?? 'pending',
  reviewNote: json['reviewNote'] as String?,
  reviewedBy: json['reviewedBy'] as String?,
  reviewedAt: const NullableTimestampConverter().fromJson(json['reviewedAt']),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
  boostedUntil: const NullableTimestampConverter().fromJson(
    json['boostedUntil'],
  ),
  activeHours: const ActiveHoursConverter().fromJson(
    json['activeHours'] as Map<String, dynamic>?,
  ),
  activeDays:
      (json['activeDays'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  birthdayMatchId: json['birthdayMatchId'] as String?,
  targetUserIds:
      (json['targetUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  personalMessage: json['personalMessage'] as String?,
);

Map<String, dynamic> _$$OfferImplToJson(
  _$OfferImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'venueId': instance.venueId,
  'venueName': instance.venueName,
  'venuePhotoUrl': instance.venuePhotoUrl,
  'category': const VenueCategoryConverter().toJson(instance.category),
  'title': instance.title,
  'description': instance.description,
  'offerType': const OfferTypeConverter().toJson(instance.offerType),
  'discountValue': instance.discountValue,
  'lat': instance.lat,
  'lng': instance.lng,
  'address': instance.address,
  'country': instance.country,
  'startDate': const TimestampConverter().toJson(instance.startDate),
  'endDate': const TimestampConverter().toJson(instance.endDate),
  'imageUrl': instance.imageUrl,
  'terms': instance.terms,
  'status': instance.status,
  'reviewNote': instance.reviewNote,
  'reviewedBy': instance.reviewedBy,
  'reviewedAt': const NullableTimestampConverter().toJson(instance.reviewedAt),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
  'boostedUntil': const NullableTimestampConverter().toJson(
    instance.boostedUntil,
  ),
  'activeHours': const ActiveHoursConverter().toJson(instance.activeHours),
  'activeDays': instance.activeDays,
  'birthdayMatchId': instance.birthdayMatchId,
  'targetUserIds': instance.targetUserIds,
  'personalMessage': instance.personalMessage,
};
