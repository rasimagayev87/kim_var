// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VenueImpl _$$VenueImplFromJson(Map<String, dynamic> json) => _$VenueImpl(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  name: json['name'] as String,
  category: const VenueCategoryConverter().fromJson(
    json['category'] as String?,
  ),
  photoUrl: json['photoUrl'] as String?,
  gallery:
      (json['gallery'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  address: json['address'] as String,
  country: json['country'] as String?,
  openingHours: const OpeningHoursConverter().fromJson(
    json['openingHours'] as Map<String, dynamic>?,
  ),
  status: json['status'] as String? ?? 'active',
  verified: json['verified'] as bool? ?? false,
  favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$$VenueImplToJson(
  _$VenueImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'name': instance.name,
  'category': const VenueCategoryConverter().toJson(instance.category),
  'photoUrl': instance.photoUrl,
  'gallery': instance.gallery,
  'lat': instance.lat,
  'lng': instance.lng,
  'address': instance.address,
  'country': instance.country,
  'openingHours': const OpeningHoursConverter().toJson(instance.openingHours),
  'status': instance.status,
  'verified': instance.verified,
  'favoriteCount': instance.favoriteCount,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
};
