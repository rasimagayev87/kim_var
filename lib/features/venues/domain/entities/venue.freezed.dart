// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Venue _$VenueFromJson(Map<String, dynamic> json) {
  return _Venue.fromJson(json);
}

/// @nodoc
mixin _$Venue {
  String get id => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @VenueCategoryConverter()
  VenueCategory get category => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;

  /// Additional photos beyond [photoUrl] — schema-ready for a future
  /// gallery/carousel on the venue profile screen. Empty until that
  /// upload flow exists; nothing writes to this yet.
  List<String> get gallery => throw _privateConstructorUsedError;
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;

  /// Reverse-geocoded alongside [address] at pick time — powers "Ölkə
  /// üzrə" discovery (same mechanism as a user's own profile country
  /// in `location_providers.dart`'s `_countryCandidatesProvider`).
  /// Null if geocoding couldn't resolve a country for the picked point.
  String? get country => throw _privateConstructorUsedError;
  @OpeningHoursConverter()
  OpeningHours get openingHours => throw _privateConstructorUsedError;

  /// Defaults to 'active' — no moderation queue exists yet, so every
  /// submitted venue is immediately visible. Kept as a string (not a
  /// bool) specifically so a future 'pending'/'approved'/'rejected'
  /// moderation flow is a value change here, not a schema migration.
  String get status => throw _privateConstructorUsedError;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  bool get verified => throw _privateConstructorUsedError;

  /// Reserved for the favorites feature (`users/{uid}/favorites`) —
  /// a denormalized counter nothing increments yet.
  int get favoriteCount => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Venue to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VenueCopyWith<Venue> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VenueCopyWith<$Res> {
  factory $VenueCopyWith(Venue value, $Res Function(Venue) then) =
      _$VenueCopyWithImpl<$Res, Venue>;
  @useResult
  $Res call({
    String id,
    String ownerId,
    String name,
    @VenueCategoryConverter() VenueCategory category,
    String? photoUrl,
    List<String> gallery,
    double lat,
    double lng,
    String address,
    String? country,
    @OpeningHoursConverter() OpeningHours openingHours,
    String status,
    bool verified,
    int favoriteCount,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class _$VenueCopyWithImpl<$Res, $Val extends Venue>
    implements $VenueCopyWith<$Res> {
  _$VenueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? name = null,
    Object? category = null,
    Object? photoUrl = freezed,
    Object? gallery = null,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? openingHours = null,
    Object? status = null,
    Object? verified = null,
    Object? favoriteCount = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerId: null == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as VenueCategory,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            gallery: null == gallery
                ? _value.gallery
                : gallery // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lat: null == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double,
            lng: null == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            openingHours: null == openingHours
                ? _value.openingHours
                : openingHours // ignore: cast_nullable_to_non_nullable
                      as OpeningHours,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            verified: null == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool,
            favoriteCount: null == favoriteCount
                ? _value.favoriteCount
                : favoriteCount // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VenueImplCopyWith<$Res> implements $VenueCopyWith<$Res> {
  factory _$$VenueImplCopyWith(
    _$VenueImpl value,
    $Res Function(_$VenueImpl) then,
  ) = __$$VenueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ownerId,
    String name,
    @VenueCategoryConverter() VenueCategory category,
    String? photoUrl,
    List<String> gallery,
    double lat,
    double lng,
    String address,
    String? country,
    @OpeningHoursConverter() OpeningHours openingHours,
    String status,
    bool verified,
    int favoriteCount,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class __$$VenueImplCopyWithImpl<$Res>
    extends _$VenueCopyWithImpl<$Res, _$VenueImpl>
    implements _$$VenueImplCopyWith<$Res> {
  __$$VenueImplCopyWithImpl(
    _$VenueImpl _value,
    $Res Function(_$VenueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? name = null,
    Object? category = null,
    Object? photoUrl = freezed,
    Object? gallery = null,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? openingHours = null,
    Object? status = null,
    Object? verified = null,
    Object? favoriteCount = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$VenueImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as VenueCategory,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        gallery: null == gallery
            ? _value._gallery
            : gallery // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lat: null == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double,
        lng: null == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        openingHours: null == openingHours
            ? _value.openingHours
            : openingHours // ignore: cast_nullable_to_non_nullable
                  as OpeningHours,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        verified: null == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool,
        favoriteCount: null == favoriteCount
            ? _value.favoriteCount
            : favoriteCount // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VenueImpl extends _Venue {
  const _$VenueImpl({
    required this.id,
    required this.ownerId,
    required this.name,
    @VenueCategoryConverter() required this.category,
    this.photoUrl,
    final List<String> gallery = const <String>[],
    required this.lat,
    required this.lng,
    required this.address,
    this.country,
    @OpeningHoursConverter() required this.openingHours,
    this.status = 'active',
    this.verified = false,
    this.favoriteCount = 0,
    @TimestampConverter() required this.createdAt,
    @NullableTimestampConverter() this.updatedAt,
  }) : _gallery = gallery,
       super._();

  factory _$VenueImpl.fromJson(Map<String, dynamic> json) =>
      _$$VenueImplFromJson(json);

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final String name;
  @override
  @VenueCategoryConverter()
  final VenueCategory category;
  @override
  final String? photoUrl;

  /// Additional photos beyond [photoUrl] — schema-ready for a future
  /// gallery/carousel on the venue profile screen. Empty until that
  /// upload flow exists; nothing writes to this yet.
  final List<String> _gallery;

  /// Additional photos beyond [photoUrl] — schema-ready for a future
  /// gallery/carousel on the venue profile screen. Empty until that
  /// upload flow exists; nothing writes to this yet.
  @override
  @JsonKey()
  List<String> get gallery {
    if (_gallery is EqualUnmodifiableListView) return _gallery;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gallery);
  }

  @override
  final double lat;
  @override
  final double lng;
  @override
  final String address;

  /// Reverse-geocoded alongside [address] at pick time — powers "Ölkə
  /// üzrə" discovery (same mechanism as a user's own profile country
  /// in `location_providers.dart`'s `_countryCandidatesProvider`).
  /// Null if geocoding couldn't resolve a country for the picked point.
  @override
  final String? country;
  @override
  @OpeningHoursConverter()
  final OpeningHours openingHours;

  /// Defaults to 'active' — no moderation queue exists yet, so every
  /// submitted venue is immediately visible. Kept as a string (not a
  /// bool) specifically so a future 'pending'/'approved'/'rejected'
  /// moderation flow is a value change here, not a schema migration.
  @override
  @JsonKey()
  final String status;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  @override
  @JsonKey()
  final bool verified;

  /// Reserved for the favorites feature (`users/{uid}/favorites`) —
  /// a denormalized counter nothing increments yet.
  @override
  @JsonKey()
  final int favoriteCount;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @NullableTimestampConverter()
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Venue(id: $id, ownerId: $ownerId, name: $name, category: $category, photoUrl: $photoUrl, gallery: $gallery, lat: $lat, lng: $lng, address: $address, country: $country, openingHours: $openingHours, status: $status, verified: $verified, favoriteCount: $favoriteCount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VenueImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            const DeepCollectionEquality().equals(other._gallery, _gallery) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.openingHours, openingHours) ||
                other.openingHours == openingHours) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.verified, verified) ||
                other.verified == verified) &&
            (identical(other.favoriteCount, favoriteCount) ||
                other.favoriteCount == favoriteCount) &&
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
    ownerId,
    name,
    category,
    photoUrl,
    const DeepCollectionEquality().hash(_gallery),
    lat,
    lng,
    address,
    country,
    openingHours,
    status,
    verified,
    favoriteCount,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VenueImplCopyWith<_$VenueImpl> get copyWith =>
      __$$VenueImplCopyWithImpl<_$VenueImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VenueImplToJson(this);
  }
}

abstract class _Venue extends Venue {
  const factory _Venue({
    required final String id,
    required final String ownerId,
    required final String name,
    @VenueCategoryConverter() required final VenueCategory category,
    final String? photoUrl,
    final List<String> gallery,
    required final double lat,
    required final double lng,
    required final String address,
    final String? country,
    @OpeningHoursConverter() required final OpeningHours openingHours,
    final String status,
    final bool verified,
    final int favoriteCount,
    @TimestampConverter() required final DateTime createdAt,
    @NullableTimestampConverter() final DateTime? updatedAt,
  }) = _$VenueImpl;
  const _Venue._() : super._();

  factory _Venue.fromJson(Map<String, dynamic> json) = _$VenueImpl.fromJson;

  @override
  String get id;
  @override
  String get ownerId;
  @override
  String get name;
  @override
  @VenueCategoryConverter()
  VenueCategory get category;
  @override
  String? get photoUrl;

  /// Additional photos beyond [photoUrl] — schema-ready for a future
  /// gallery/carousel on the venue profile screen. Empty until that
  /// upload flow exists; nothing writes to this yet.
  @override
  List<String> get gallery;
  @override
  double get lat;
  @override
  double get lng;
  @override
  String get address;

  /// Reverse-geocoded alongside [address] at pick time — powers "Ölkə
  /// üzrə" discovery (same mechanism as a user's own profile country
  /// in `location_providers.dart`'s `_countryCandidatesProvider`).
  /// Null if geocoding couldn't resolve a country for the picked point.
  @override
  String? get country;
  @override
  @OpeningHoursConverter()
  OpeningHours get openingHours;

  /// Defaults to 'active' — no moderation queue exists yet, so every
  /// submitted venue is immediately visible. Kept as a string (not a
  /// bool) specifically so a future 'pending'/'approved'/'rejected'
  /// moderation flow is a value change here, not a schema migration.
  @override
  String get status;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  @override
  bool get verified;

  /// Reserved for the favorites feature (`users/{uid}/favorites`) —
  /// a denormalized counter nothing increments yet.
  @override
  int get favoriteCount;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @NullableTimestampConverter()
  DateTime? get updatedAt;

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueImplCopyWith<_$VenueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
