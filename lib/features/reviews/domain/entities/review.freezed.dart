// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReviewOwnerReply _$ReviewOwnerReplyFromJson(Map<String, dynamic> json) {
  return _ReviewOwnerReply.fromJson(json);
}

/// @nodoc
mixin _$ReviewOwnerReply {
  String get text => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get repliedAt => throw _privateConstructorUsedError;

  /// Serializes this ReviewOwnerReply to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewOwnerReply
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewOwnerReplyCopyWith<ReviewOwnerReply> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewOwnerReplyCopyWith<$Res> {
  factory $ReviewOwnerReplyCopyWith(
    ReviewOwnerReply value,
    $Res Function(ReviewOwnerReply) then,
  ) = _$ReviewOwnerReplyCopyWithImpl<$Res, ReviewOwnerReply>;
  @useResult
  $Res call({String text, @TimestampConverter() DateTime repliedAt});
}

/// @nodoc
class _$ReviewOwnerReplyCopyWithImpl<$Res, $Val extends ReviewOwnerReply>
    implements $ReviewOwnerReplyCopyWith<$Res> {
  _$ReviewOwnerReplyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewOwnerReply
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null, Object? repliedAt = null}) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            repliedAt: null == repliedAt
                ? _value.repliedAt
                : repliedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewOwnerReplyImplCopyWith<$Res>
    implements $ReviewOwnerReplyCopyWith<$Res> {
  factory _$$ReviewOwnerReplyImplCopyWith(
    _$ReviewOwnerReplyImpl value,
    $Res Function(_$ReviewOwnerReplyImpl) then,
  ) = __$$ReviewOwnerReplyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, @TimestampConverter() DateTime repliedAt});
}

/// @nodoc
class __$$ReviewOwnerReplyImplCopyWithImpl<$Res>
    extends _$ReviewOwnerReplyCopyWithImpl<$Res, _$ReviewOwnerReplyImpl>
    implements _$$ReviewOwnerReplyImplCopyWith<$Res> {
  __$$ReviewOwnerReplyImplCopyWithImpl(
    _$ReviewOwnerReplyImpl _value,
    $Res Function(_$ReviewOwnerReplyImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewOwnerReply
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null, Object? repliedAt = null}) {
    return _then(
      _$ReviewOwnerReplyImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        repliedAt: null == repliedAt
            ? _value.repliedAt
            : repliedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewOwnerReplyImpl implements _ReviewOwnerReply {
  const _$ReviewOwnerReplyImpl({
    required this.text,
    @TimestampConverter() required this.repliedAt,
  });

  factory _$ReviewOwnerReplyImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewOwnerReplyImplFromJson(json);

  @override
  final String text;
  @override
  @TimestampConverter()
  final DateTime repliedAt;

  @override
  String toString() {
    return 'ReviewOwnerReply(text: $text, repliedAt: $repliedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewOwnerReplyImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.repliedAt, repliedAt) ||
                other.repliedAt == repliedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, text, repliedAt);

  /// Create a copy of ReviewOwnerReply
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewOwnerReplyImplCopyWith<_$ReviewOwnerReplyImpl> get copyWith =>
      __$$ReviewOwnerReplyImplCopyWithImpl<_$ReviewOwnerReplyImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewOwnerReplyImplToJson(this);
  }
}

abstract class _ReviewOwnerReply implements ReviewOwnerReply {
  const factory _ReviewOwnerReply({
    required final String text,
    @TimestampConverter() required final DateTime repliedAt,
  }) = _$ReviewOwnerReplyImpl;

  factory _ReviewOwnerReply.fromJson(Map<String, dynamic> json) =
      _$ReviewOwnerReplyImpl.fromJson;

  @override
  String get text;
  @override
  @TimestampConverter()
  DateTime get repliedAt;

  /// Create a copy of ReviewOwnerReply
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewOwnerReplyImplCopyWith<_$ReviewOwnerReplyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Review _$ReviewFromJson(Map<String, dynamic> json) {
  return _Review.fromJson(json);
}

/// @nodoc
mixin _$Review {
  String get id => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  int get rating => throw _privateConstructorUsedError;
  String get comment => throw _privateConstructorUsedError;
  String get waitlistEntryId => throw _privateConstructorUsedError;
  ReviewOwnerReply? get ownerReply => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Review to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewCopyWith<Review> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewCopyWith<$Res> {
  factory $ReviewCopyWith(Review value, $Res Function(Review) then) =
      _$ReviewCopyWithImpl<$Res, Review>;
  @useResult
  $Res call({
    String id,
    String venueId,
    String userId,
    int rating,
    String comment,
    String waitlistEntryId,
    ReviewOwnerReply? ownerReply,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime updatedAt,
  });

  $ReviewOwnerReplyCopyWith<$Res>? get ownerReply;
}

/// @nodoc
class _$ReviewCopyWithImpl<$Res, $Val extends Review>
    implements $ReviewCopyWith<$Res> {
  _$ReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? userId = null,
    Object? rating = null,
    Object? comment = null,
    Object? waitlistEntryId = null,
    Object? ownerReply = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
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
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: null == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String,
            waitlistEntryId: null == waitlistEntryId
                ? _value.waitlistEntryId
                : waitlistEntryId // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerReply: freezed == ownerReply
                ? _value.ownerReply
                : ownerReply // ignore: cast_nullable_to_non_nullable
                      as ReviewOwnerReply?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReviewOwnerReplyCopyWith<$Res>? get ownerReply {
    if (_value.ownerReply == null) {
      return null;
    }

    return $ReviewOwnerReplyCopyWith<$Res>(_value.ownerReply!, (value) {
      return _then(_value.copyWith(ownerReply: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReviewImplCopyWith<$Res> implements $ReviewCopyWith<$Res> {
  factory _$$ReviewImplCopyWith(
    _$ReviewImpl value,
    $Res Function(_$ReviewImpl) then,
  ) = __$$ReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String venueId,
    String userId,
    int rating,
    String comment,
    String waitlistEntryId,
    ReviewOwnerReply? ownerReply,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime updatedAt,
  });

  @override
  $ReviewOwnerReplyCopyWith<$Res>? get ownerReply;
}

/// @nodoc
class __$$ReviewImplCopyWithImpl<$Res>
    extends _$ReviewCopyWithImpl<$Res, _$ReviewImpl>
    implements _$$ReviewImplCopyWith<$Res> {
  __$$ReviewImplCopyWithImpl(
    _$ReviewImpl _value,
    $Res Function(_$ReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? userId = null,
    Object? rating = null,
    Object? comment = null,
    Object? waitlistEntryId = null,
    Object? ownerReply = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ReviewImpl(
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
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: null == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String,
        waitlistEntryId: null == waitlistEntryId
            ? _value.waitlistEntryId
            : waitlistEntryId // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerReply: freezed == ownerReply
            ? _value.ownerReply
            : ownerReply // ignore: cast_nullable_to_non_nullable
                  as ReviewOwnerReply?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewImpl extends _Review {
  const _$ReviewImpl({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.waitlistEntryId,
    this.ownerReply,
    @TimestampConverter() required this.createdAt,
    @TimestampConverter() required this.updatedAt,
  }) : super._();

  factory _$ReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewImplFromJson(json);

  @override
  final String id;
  @override
  final String venueId;
  @override
  final String userId;
  @override
  final int rating;
  @override
  final String comment;
  @override
  final String waitlistEntryId;
  @override
  final ReviewOwnerReply? ownerReply;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @TimestampConverter()
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Review(id: $id, venueId: $venueId, userId: $userId, rating: $rating, comment: $comment, waitlistEntryId: $waitlistEntryId, ownerReply: $ownerReply, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.waitlistEntryId, waitlistEntryId) ||
                other.waitlistEntryId == waitlistEntryId) &&
            (identical(other.ownerReply, ownerReply) ||
                other.ownerReply == ownerReply) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    venueId,
    userId,
    rating,
    comment,
    waitlistEntryId,
    ownerReply,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      __$$ReviewImplCopyWithImpl<_$ReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewImplToJson(this);
  }
}

abstract class _Review extends Review {
  const factory _Review({
    required final String id,
    required final String venueId,
    required final String userId,
    required final int rating,
    required final String comment,
    required final String waitlistEntryId,
    final ReviewOwnerReply? ownerReply,
    @TimestampConverter() required final DateTime createdAt,
    @TimestampConverter() required final DateTime updatedAt,
  }) = _$ReviewImpl;
  const _Review._() : super._();

  factory _Review.fromJson(Map<String, dynamic> json) = _$ReviewImpl.fromJson;

  @override
  String get id;
  @override
  String get venueId;
  @override
  String get userId;
  @override
  int get rating;
  @override
  String get comment;
  @override
  String get waitlistEntryId;
  @override
  ReviewOwnerReply? get ownerReply;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @TimestampConverter()
  DateTime get updatedAt;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
