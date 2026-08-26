// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waitlist_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WaitlistEntryImpl _$$WaitlistEntryImplFromJson(Map<String, dynamic> json) =>
    _$WaitlistEntryImpl(
      id: json['id'] as String,
      venueId: json['venueId'] as String,
      userId: json['userId'] as String,
      partySize: (json['partySize'] as num).toInt(),
      phoneNumber: json['phoneNumber'] as String,
      note: json['note'] as String?,
      status: json['status'] == null
          ? WaitlistEntryStatus.waiting
          : const WaitlistEntryStatusConverter().fromJson(
              json['status'] as String?,
            ),
      joinedAt: const TimestampConverter().fromJson(json['joinedAt']),
      calledAt: const NullableTimestampConverter().fromJson(json['calledAt']),
      seatedAt: const NullableTimestampConverter().fromJson(json['seatedAt']),
      queuePosition: (json['queuePosition'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$WaitlistEntryImplToJson(_$WaitlistEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venueId': instance.venueId,
      'userId': instance.userId,
      'partySize': instance.partySize,
      'phoneNumber': instance.phoneNumber,
      'note': instance.note,
      'status': const WaitlistEntryStatusConverter().toJson(instance.status),
      'joinedAt': const TimestampConverter().toJson(instance.joinedAt),
      'calledAt': const NullableTimestampConverter().toJson(instance.calledAt),
      'seatedAt': const NullableTimestampConverter().toJson(instance.seatedAt),
      'queuePosition': instance.queuePosition,
    };
