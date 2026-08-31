// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VenueEvent _$VenueEventFromJson(Map<String, dynamic> json) {
  return _VenueEvent.fromJson(json);
}

/// @nodoc
mixin _$VenueEvent {
  String get id => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get venueName => throw _privateConstructorUsedError;
  String? get venuePhotoUrl => throw _privateConstructorUsedError;
  @VenueCategoryConverter()
  VenueCategory get venueCategory => throw _privateConstructorUsedError;
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get startAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get endAt => throw _privateConstructorUsedError;
  @VenueEventCategoryConverter()
  VenueEventCategory get category => throw _privateConstructorUsedError;
  @VenueEventStatusConverter()
  VenueEventStatus get status => throw _privateConstructorUsedError;

  /// Why an event was rejected — a moderator's note, or the automatic
  /// one written when a `pending` event reached its own `startAt`
  /// before anyone reviewed it. Shown on the owner's own card,
  /// because that rejection is the product's delay rather than the
  /// owner's mistake and they can only act on it if they are told.
  String? get reviewNote => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this VenueEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VenueEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VenueEventCopyWith<VenueEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VenueEventCopyWith<$Res> {
  factory $VenueEventCopyWith(
    VenueEvent value,
    $Res Function(VenueEvent) then,
  ) = _$VenueEventCopyWithImpl<$Res, VenueEvent>;
  @useResult
  $Res call({
    String id,
    String venueId,
    String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() VenueCategory venueCategory,
    double lat,
    double lng,
    String title,
    String description,
    String? coverImageUrl,
    @TimestampConverter() DateTime startAt,
    @TimestampConverter() DateTime endAt,
    @VenueEventCategoryConverter() VenueEventCategory category,
    @VenueEventStatusConverter() VenueEventStatus status,
    String? reviewNote,
    @TimestampConverter() DateTime createdAt,
  });
}

/// @nodoc
class _$VenueEventCopyWithImpl<$Res, $Val extends VenueEvent>
    implements $VenueEventCopyWith<$Res> {
  _$VenueEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VenueEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? venueName = null,
    Object? venuePhotoUrl = freezed,
    Object? venueCategory = null,
    Object? lat = null,
    Object? lng = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? startAt = null,
    Object? endAt = null,
    Object? category = null,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? createdAt = null,
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
            venueName: null == venueName
                ? _value.venueName
                : venueName // ignore: cast_nullable_to_non_nullable
                      as String,
            venuePhotoUrl: freezed == venuePhotoUrl
                ? _value.venuePhotoUrl
                : venuePhotoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            venueCategory: null == venueCategory
                ? _value.venueCategory
                : venueCategory // ignore: cast_nullable_to_non_nullable
                      as VenueCategory,
            lat: null == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double,
            lng: null == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            startAt: null == startAt
                ? _value.startAt
                : startAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endAt: null == endAt
                ? _value.endAt
                : endAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as VenueEventCategory,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as VenueEventStatus,
            reviewNote: freezed == reviewNote
                ? _value.reviewNote
                : reviewNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VenueEventImplCopyWith<$Res>
    implements $VenueEventCopyWith<$Res> {
  factory _$$VenueEventImplCopyWith(
    _$VenueEventImpl value,
    $Res Function(_$VenueEventImpl) then,
  ) = __$$VenueEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String venueId,
    String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() VenueCategory venueCategory,
    double lat,
    double lng,
    String title,
    String description,
    String? coverImageUrl,
    @TimestampConverter() DateTime startAt,
    @TimestampConverter() DateTime endAt,
    @VenueEventCategoryConverter() VenueEventCategory category,
    @VenueEventStatusConverter() VenueEventStatus status,
    String? reviewNote,
    @TimestampConverter() DateTime createdAt,
  });
}

/// @nodoc
class __$$VenueEventImplCopyWithImpl<$Res>
    extends _$VenueEventCopyWithImpl<$Res, _$VenueEventImpl>
    implements _$$VenueEventImplCopyWith<$Res> {
  __$$VenueEventImplCopyWithImpl(
    _$VenueEventImpl _value,
    $Res Function(_$VenueEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VenueEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? venueId = null,
    Object? venueName = null,
    Object? venuePhotoUrl = freezed,
    Object? venueCategory = null,
    Object? lat = null,
    Object? lng = null,
    Object? title = null,
    Object? description = null,
    Object? coverImageUrl = freezed,
    Object? startAt = null,
    Object? endAt = null,
    Object? category = null,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$VenueEventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        venueId: null == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String,
        venueName: null == venueName
            ? _value.venueName
            : venueName // ignore: cast_nullable_to_non_nullable
                  as String,
        venuePhotoUrl: freezed == venuePhotoUrl
            ? _value.venuePhotoUrl
            : venuePhotoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        venueCategory: null == venueCategory
            ? _value.venueCategory
            : venueCategory // ignore: cast_nullable_to_non_nullable
                  as VenueCategory,
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        startAt: null == startAt
            ? _value.startAt
            : startAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endAt: null == endAt
            ? _value.endAt
            : endAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as VenueEventCategory,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as VenueEventStatus,
        reviewNote: freezed == reviewNote
            ? _value.reviewNote
            : reviewNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VenueEventImpl extends _VenueEvent {
  const _$VenueEventImpl({
    required this.id,
    required this.venueId,
    required this.venueName,
    this.venuePhotoUrl,
    @VenueCategoryConverter() this.venueCategory = VenueCategory.other,
    required this.lat,
    required this.lng,
    required this.title,
    required this.description,
    this.coverImageUrl,
    @TimestampConverter() required this.startAt,
    @TimestampConverter() required this.endAt,
    @VenueEventCategoryConverter() this.category = VenueEventCategory.other,
    @VenueEventStatusConverter() this.status = VenueEventStatus.pending,
    this.reviewNote,
    @TimestampConverter() required this.createdAt,
  }) : super._();

  factory _$VenueEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$VenueEventImplFromJson(json);

  @override
  final String id;
  @override
  final String venueId;
  @override
  final String venueName;
  @override
  final String? venuePhotoUrl;
  @override
  @JsonKey()
  @VenueCategoryConverter()
  final VenueCategory venueCategory;
  @override
  final double lat;
  @override
  final double lng;
  @override
  final String title;
  @override
  final String description;
  @override
  final String? coverImageUrl;
  @override
  @TimestampConverter()
  final DateTime startAt;
  @override
  @TimestampConverter()
  final DateTime endAt;
  @override
  @JsonKey()
  @VenueEventCategoryConverter()
  final VenueEventCategory category;
  @override
  @JsonKey()
  @VenueEventStatusConverter()
  final VenueEventStatus status;

  /// Why an event was rejected — a moderator's note, or the automatic
  /// one written when a `pending` event reached its own `startAt`
  /// before anyone reviewed it. Shown on the owner's own card,
  /// because that rejection is the product's delay rather than the
  /// owner's mistake and they can only act on it if they are told.
  @override
  final String? reviewNote;
  @override
  @TimestampConverter()
  final DateTime createdAt;

  @override
  String toString() {
    return 'VenueEvent(id: $id, venueId: $venueId, venueName: $venueName, venuePhotoUrl: $venuePhotoUrl, venueCategory: $venueCategory, lat: $lat, lng: $lng, title: $title, description: $description, coverImageUrl: $coverImageUrl, startAt: $startAt, endAt: $endAt, category: $category, status: $status, reviewNote: $reviewNote, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VenueEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.venueName, venueName) ||
                other.venueName == venueName) &&
            (identical(other.venuePhotoUrl, venuePhotoUrl) ||
                other.venuePhotoUrl == venuePhotoUrl) &&
            (identical(other.venueCategory, venueCategory) ||
                other.venueCategory == venueCategory) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewNote, reviewNote) ||
                other.reviewNote == reviewNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    venueId,
    venueName,
    venuePhotoUrl,
    venueCategory,
    lat,
    lng,
    title,
    description,
    coverImageUrl,
    startAt,
    endAt,
    category,
    status,
    reviewNote,
    createdAt,
  );

  /// Create a copy of VenueEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VenueEventImplCopyWith<_$VenueEventImpl> get copyWith =>
      __$$VenueEventImplCopyWithImpl<_$VenueEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VenueEventImplToJson(this);
  }
}

abstract class _VenueEvent extends VenueEvent {
  const factory _VenueEvent({
    required final String id,
    required final String venueId,
    required final String venueName,
    final String? venuePhotoUrl,
    @VenueCategoryConverter() final VenueCategory venueCategory,
    required final double lat,
    required final double lng,
    required final String title,
    required final String description,
    final String? coverImageUrl,
    @TimestampConverter() required final DateTime startAt,
    @TimestampConverter() required final DateTime endAt,
    @VenueEventCategoryConverter() final VenueEventCategory category,
    @VenueEventStatusConverter() final VenueEventStatus status,
    final String? reviewNote,
    @TimestampConverter() required final DateTime createdAt,
  }) = _$VenueEventImpl;
  const _VenueEvent._() : super._();

  factory _VenueEvent.fromJson(Map<String, dynamic> json) =
      _$VenueEventImpl.fromJson;

  @override
  String get id;
  @override
  String get venueId;
  @override
  String get venueName;
  @override
  String? get venuePhotoUrl;
  @override
  @VenueCategoryConverter()
  VenueCategory get venueCategory;
  @override
  double get lat;
  @override
  double get lng;
  @override
  String get title;
  @override
  String get description;
  @override
  String? get coverImageUrl;
  @override
  @TimestampConverter()
  DateTime get startAt;
  @override
  @TimestampConverter()
  DateTime get endAt;
  @override
  @VenueEventCategoryConverter()
  VenueEventCategory get category;
  @override
  @VenueEventStatusConverter()
  VenueEventStatus get status;

  /// Why an event was rejected — a moderator's note, or the automatic
  /// one written when a `pending` event reached its own `startAt`
  /// before anyone reviewed it. Shown on the owner's own card,
  /// because that rejection is the product's delay rather than the
  /// owner's mistake and they can only act on it if they are told.
  @override
  String? get reviewNote;
  @override
  @TimestampConverter()
  DateTime get createdAt;

  /// Create a copy of VenueEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueEventImplCopyWith<_$VenueEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
