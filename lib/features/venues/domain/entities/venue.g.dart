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
  status: json['status'] as String? ?? 'pending',
  reviewNote: json['reviewNote'] as String?,
  reviewedBy: json['reviewedBy'] as String?,
  reviewedAt: const NullableTimestampConverter().fromJson(json['reviewedAt']),
  paymentId: json['paymentId'] as String?,
  subscriptionRenewsAt: const NullableTimestampConverter().fromJson(
    json['subscriptionRenewsAt'],
  ),
  isFoundingVenue: json['isFoundingVenue'] as bool? ?? false,
  freeOffersUsed: (json['freeOffersUsed'] as num?)?.toInt() ?? 0,
  freeOfferWindowEnd: const NullableTimestampConverter().fromJson(
    json['freeOfferWindowEnd'],
  ),
  firstPaymentAnnouncementPending:
      json['firstPaymentAnnouncementPending'] as bool? ?? false,
  revisionDeadline: const NullableTimestampConverter().fromJson(
    json['revisionDeadline'],
  ),
  verified: json['verified'] as bool? ?? false,
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  rating: (json['rating'] as num?)?.toDouble() ?? 3.0,
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
  socialLinks: const VenueSocialLinksConverter().fromJson(
    json['socialLinks'] as Map<String, dynamic>?,
  ),
  audienceRadiusMode: json['audienceRadiusMode'] as String? ?? 'distance',
  audienceRadiusKm: (json['audienceRadiusKm'] as num?)?.toDouble() ?? 1.0,
  isPremium: json['isPremium'] as bool? ?? false,
  premiumSince: const NullableTimestampConverter().fromJson(
    json['premiumSince'],
  ),
  birthdayNotificationsEnabled:
      json['birthdayNotificationsEnabled'] as bool? ?? false,
  availableSeats: (json['availableSeats'] as num?)?.toInt(),
  seatsUpdatedAt: const NullableTimestampConverter().fromJson(
    json['seatsUpdatedAt'],
  ),
  waitlistEnabled: json['waitlistEnabled'] as bool? ?? false,
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
  'reviewNote': instance.reviewNote,
  'reviewedBy': instance.reviewedBy,
  'reviewedAt': const NullableTimestampConverter().toJson(instance.reviewedAt),
  'paymentId': instance.paymentId,
  'subscriptionRenewsAt': const NullableTimestampConverter().toJson(
    instance.subscriptionRenewsAt,
  ),
  'isFoundingVenue': instance.isFoundingVenue,
  'freeOffersUsed': instance.freeOffersUsed,
  'freeOfferWindowEnd': const NullableTimestampConverter().toJson(
    instance.freeOfferWindowEnd,
  ),
  'firstPaymentAnnouncementPending': instance.firstPaymentAnnouncementPending,
  'revisionDeadline': const NullableTimestampConverter().toJson(
    instance.revisionDeadline,
  ),
  'verified': instance.verified,
  'likeCount': instance.likeCount,
  'rating': instance.rating,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
  'socialLinks': const VenueSocialLinksConverter().toJson(instance.socialLinks),
  'audienceRadiusMode': instance.audienceRadiusMode,
  'audienceRadiusKm': instance.audienceRadiusKm,
  'isPremium': instance.isPremium,
  'premiumSince': const NullableTimestampConverter().toJson(
    instance.premiumSince,
  ),
  'birthdayNotificationsEnabled': instance.birthdayNotificationsEnabled,
  'availableSeats': instance.availableSeats,
  'seatsUpdatedAt': const NullableTimestampConverter().toJson(
    instance.seatsUpdatedAt,
  ),
  'waitlistEnabled': instance.waitlistEnabled,
};
