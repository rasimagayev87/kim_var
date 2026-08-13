// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'waitlist_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WaitlistEntry _$WaitlistEntryFromJson(Map<String, dynamic> json) {
  return _WaitlistEntry.fromJson(json);
}

/// @nodoc
mixin _$WaitlistEntry {
  String get id => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  int get partySize => throw _privateConstructorUsedError;
  @WaitlistEntryStatusConverter()
  WaitlistEntryStatus get status => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get joinedAt => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get calledAt => throw _privateConstructorUsedError;

  /// Only ever set while [status] is [WaitlistEntryStatus.waiting] —
  /// null for every other status (a called/seated/cancelled/no-show
  /// entry isn't "in line" anymore).
  int? get queuePosition => throw _privateConstructorUsedError;

  /// Serializes this WaitlistEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WaitlistEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WaitlistEntryCopyWith<WaitlistEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WaitlistEntryCopyWith<$Res> {
  factory $WaitlistEntryCopyWith(
    WaitlistEntry value,
    $Res Function(WaitlistEntry) then,
  ) = _$WaitlistEntryCopyWithImpl<$Res, WaitlistEntry>;
  @useResult
  $Res call({
    String id,
    String venueId,
    String userId,
    int partySize,
    @WaitlistEntryStatusConverter() WaitlistEntryStatus status,
    @TimestampConverter() DateTime joinedAt,
    @NullableTimestampConverter() DateTime? calledAt,
    int? queuePosition,
  });
}

/// @nodoc
class _$WaitlistEntryCopyWithImpl<$Res, $Val extends WaitlistEntry>
    implements $WaitlistEntryCopyWith<$Res> {
  _$WaitlistEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WaitlistEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? userId = null,
    Object? partySize = null,
    Object? status = null,
    Object? joinedAt = null,
    Object? calledAt = freezed,
    Object? queuePosition = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            venueId: null == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            partySize: null == partySize
                ? _value.partySize
                : partySize // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as WaitlistEntryStatus,
            joinedAt: null == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            calledAt: freezed == calledAt
                ? _value.calledAt
                : calledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            queuePosition: freezed == queuePosition
                ? _value.queuePosition
                : queuePosition // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WaitlistEntryImplCopyWith<$Res>
    implements $WaitlistEntryCopyWith<$Res> {
  factory _$$WaitlistEntryImplCopyWith(
    _$WaitlistEntryImpl value,
    $Res Function(_$WaitlistEntryImpl) then,
  ) = __$$WaitlistEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String venueId,
    String userId,
    int partySize,
    @WaitlistEntryStatusConverter() WaitlistEntryStatus status,
    @TimestampConverter() DateTime joinedAt,
    @NullableTimestampConverter() DateTime? calledAt,
    int? queuePosition,
  });
}

/// @nodoc
class __$$WaitlistEntryImplCopyWithImpl<$Res>
    extends _$WaitlistEntryCopyWithImpl<$Res, _$WaitlistEntryImpl>
    implements _$$WaitlistEntryImplCopyWith<$Res> {
  __$$WaitlistEntryImplCopyWithImpl(
    _$WaitlistEntryImpl _value,
    $Res Function(_$WaitlistEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WaitlistEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? userId = null,
    Object? partySize = null,
    Object? status = null,
    Object? joinedAt = null,
    Object? calledAt = freezed,
    Object? queuePosition = freezed,
  }) {
    return _then(
      _$WaitlistEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        partySize: null == partySize
            ? _value.partySize
            : partySize // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as WaitlistEntryStatus,
        joinedAt: null == joinedAt
            ? _value.joinedAt
            : joinedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        calledAt: freezed == calledAt
            ? _value.calledAt
            : calledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        queuePosition: freezed == queuePosition
            ? _value.queuePosition
            : queuePosition // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WaitlistEntryImpl extends _WaitlistEntry {
  const _$WaitlistEntryImpl({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.partySize,
    @WaitlistEntryStatusConverter() this.status = WaitlistEntryStatus.waiting,
    @TimestampConverter() required this.joinedAt,
    @NullableTimestampConverter() this.calledAt,
    this.queuePosition,
  }) : super._();

  factory _$WaitlistEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$WaitlistEntryImplFromJson(json);

  @override
  final String id;
  @override
  final String venueId;
  @override
  final String userId;
  @override
  final int partySize;
  @override
  @JsonKey()
  @WaitlistEntryStatusConverter()
  final WaitlistEntryStatus status;
  @override
  @TimestampConverter()
  final DateTime joinedAt;
  @override
  @NullableTimestampConverter()
  final DateTime? calledAt;

  /// Only ever set while [status] is [WaitlistEntryStatus.waiting] —
  /// null for every other status (a called/seated/cancelled/no-show
  /// entry isn't "in line" anymore).
  @override
  final int? queuePosition;

  @override
  String toString() {
    return 'WaitlistEntry(id: $id, venueId: $venueId, userId: $userId, partySize: $partySize, status: $status, joinedAt: $joinedAt, calledAt: $calledAt, queuePosition: $queuePosition)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WaitlistEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.partySize, partySize) ||
                other.partySize == partySize) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.calledAt, calledAt) ||
                other.calledAt == calledAt) &&
            (identical(other.queuePosition, queuePosition) ||
                other.queuePosition == queuePosition));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    venueId,
    userId,
    partySize,
    status,
    joinedAt,
    calledAt,
    queuePosition,
  );

  /// Create a copy of WaitlistEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WaitlistEntryImplCopyWith<_$WaitlistEntryImpl> get copyWith =>
      __$$WaitlistEntryImplCopyWithImpl<_$WaitlistEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WaitlistEntryImplToJson(this);
  }
}

abstract class _WaitlistEntry extends WaitlistEntry {
  const factory _WaitlistEntry({
    required final String id,
    required final String venueId,
    required final String userId,
    required final int partySize,
    @WaitlistEntryStatusConverter() final WaitlistEntryStatus status,
    @TimestampConverter() required final DateTime joinedAt,
    @NullableTimestampConverter() final DateTime? calledAt,
    final int? queuePosition,
  }) = _$WaitlistEntryImpl;
  const _WaitlistEntry._() : super._();

  factory _WaitlistEntry.fromJson(Map<String, dynamic> json) =
      _$WaitlistEntryImpl.fromJson;

  @override
  String get id;
  @override
  String get venueId;
  @override
  String get userId;
  @override
  int get partySize;
  @override
  @WaitlistEntryStatusConverter()
  WaitlistEntryStatus get status;
  @override
  @TimestampConverter()
  DateTime get joinedAt;
  @override
  @NullableTimestampConverter()
  DateTime? get calledAt;

  /// Only ever set while [status] is [WaitlistEntryStatus.waiting] —
  /// null for every other status (a called/seated/cancelled/no-show
  /// entry isn't "in line" anymore).
  @override
  int? get queuePosition;

  /// Create a copy of WaitlistEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaitlistEntryImplCopyWith<_$WaitlistEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
