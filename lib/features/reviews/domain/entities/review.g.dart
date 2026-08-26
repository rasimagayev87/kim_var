// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReviewOwnerReplyImpl _$$ReviewOwnerReplyImplFromJson(
  Map<String, dynamic> json,
) => _$ReviewOwnerReplyImpl(
  text: json['text'] as String,
  repliedAt: const TimestampConverter().fromJson(json['repliedAt']),
);

Map<String, dynamic> _$$ReviewOwnerReplyImplToJson(
  _$ReviewOwnerReplyImpl instance,
) => <String, dynamic>{
  'text': instance.text,
  'repliedAt': const TimestampConverter().toJson(instance.repliedAt),
};

_$ReviewImpl _$$ReviewImplFromJson(Map<String, dynamic> json) => _$ReviewImpl(
  id: json['id'] as String,
  venueId: json['venueId'] as String,
  userId: json['userId'] as String,
  rating: (json['rating'] as num).toInt(),
  comment: json['comment'] as String,
  waitlistEntryId: json['waitlistEntryId'] as String,
  ownerReply: json['ownerReply'] == null
      ? null
      : ReviewOwnerReply.fromJson(json['ownerReply'] as Map<String, dynamic>),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const TimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$$ReviewImplToJson(_$ReviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venueId': instance.venueId,
      'userId': instance.userId,
      'rating': instance.rating,
      'comment': instance.comment,
      'waitlistEntryId': instance.waitlistEntryId,
      'ownerReply': instance.ownerReply,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
    };
