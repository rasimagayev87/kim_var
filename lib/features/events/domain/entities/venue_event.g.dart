// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VenueEventImpl _$$VenueEventImplFromJson(Map<String, dynamic> json) =>
    _$VenueEventImpl(
      id: json['id'] as String,
      venueId: json['venueId'] as String,
      venueName: json['venueName'] as String,
      venuePhotoUrl: json['venuePhotoUrl'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      title: json['title'] as String,
      description: json['description'] as String,
      coverImageUrl: json['coverImageUrl'] as String?,
      startAt: const TimestampConverter().fromJson(json['startAt']),
      endAt: const TimestampConverter().fromJson(json['endAt']),
      category: json['category'] == null
          ? VenueEventCategory.other
          : const VenueEventCategoryConverter().fromJson(
              json['category'] as String?,
            ),
      status: json['status'] == null
          ? VenueEventStatus.upcoming
          : const VenueEventStatusConverter().fromJson(
              json['status'] as String?,
            ),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
    );

Map<String, dynamic> _$$VenueEventImplToJson(_$VenueEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venueId': instance.venueId,
      'venueName': instance.venueName,
      'venuePhotoUrl': instance.venuePhotoUrl,
      'lat': instance.lat,
      'lng': instance.lng,
      'title': instance.title,
      'description': instance.description,
      'coverImageUrl': instance.coverImageUrl,
      'startAt': const TimestampConverter().toJson(instance.startAt),
      'endAt': const TimestampConverter().toJson(instance.endAt),
      'category': const VenueEventCategoryConverter().toJson(instance.category),
      'status': const VenueEventStatusConverter().toJson(instance.status),
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
    };
