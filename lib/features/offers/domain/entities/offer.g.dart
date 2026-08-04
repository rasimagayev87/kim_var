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
  contactPhone: json['contactPhone'] as String?,
  showContactPhone: json['showContactPhone'] as bool? ?? false,
  contactWebsite: json['contactWebsite'] as String?,
  showContactWebsite: json['showContactWebsite'] as bool? ?? false,
  contactInstagram: json['contactInstagram'] as String?,
  showContactInstagram: json['showContactInstagram'] as bool? ?? false,
  status: json['status'] as String? ?? 'active',
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
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
  'contactPhone': instance.contactPhone,
  'showContactPhone': instance.showContactPhone,
  'contactWebsite': instance.contactWebsite,
  'showContactWebsite': instance.showContactWebsite,
  'contactInstagram': instance.contactInstagram,
  'showContactInstagram': instance.showContactInstagram,
  'status': instance.status,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
};
