// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pinbox.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PinBox _$PinBoxFromJson(Map<String, dynamic> json) {
  return _PinBox.fromJson(json);
}

/// @nodoc
mixin _$PinBox {
  String get id => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get venueName => throw _privateConstructorUsedError;
  String? get venuePhotoUrl => throw _privateConstructorUsedError;
  @VenueCategoryConverter()
  VenueCategory get category => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;

  /// Menu/original value of the box's contents — struck through next
  /// to [pinboxPrice] on every card, same visual convention as the
  /// reference mockups.
  double get originalPrice => throw _privateConstructorUsedError;

  /// What the buyer actually pays — [discountPercent] is always
  /// derived from these two, never stored separately, so the two
  /// numbers can't silently drift.
  double get pinboxPrice => throw _privateConstructorUsedError;
  int get stockTotal => throw _privateConstructorUsedError;

  /// Client-visible cache of remaining stock — the SOURCE of truth is
  /// server-side (a Cloud Function transaction decrements this
  /// atomically on each successful order, see PinBox Faza 7's doc
  /// comment on why the non-transactional `availableSeats` pattern
  /// was deliberately NOT reused here). Locked from direct client
  /// writes in firestore.rules.
  int get stockRemaining => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get pickupWindowStart => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get pickupWindowEnd => throw _privateConstructorUsedError;

  /// 'pending' | 'active' | 'soldOut' | 'expired' | 'rejected' |
  /// 'needs_revision' — same moderation lifecycle shape as
  /// [Offer.status]/[Venue.status]; only the admin panel's Server
  /// Actions may move it off 'pending'. Unlike Offer/Venue there's no
  /// `revisionDeadline` field — a PinBox listing has no upfront fee
  /// to protect with an auto-reject/refund clock, so 'needs_revision'
  /// just waits on the owner's own resubmission via `resubmitPinBox`.
  String get status => throw _privateConstructorUsedError;
  String? get reviewNote => throw _privateConstructorUsedError;
  String? get reviewedBy => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this PinBox to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PinBox
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PinBoxCopyWith<PinBox> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PinBoxCopyWith<$Res> {
  factory $PinBoxCopyWith(PinBox value, $Res Function(PinBox) then) =
      _$PinBoxCopyWithImpl<$Res, PinBox>;
  @useResult
  $Res call({
    String id,
    String ownerId,
    String venueId,
    String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() VenueCategory category,
    String title,
    String description,
    String? imageUrl,
    double lat,
    double lng,
    String address,
    String? country,
    double originalPrice,
    double pinboxPrice,
    int stockTotal,
    int stockRemaining,
    @TimestampConverter() DateTime pickupWindowStart,
    @TimestampConverter() DateTime pickupWindowEnd,
    String status,
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class _$PinBoxCopyWithImpl<$Res, $Val extends PinBox>
    implements $PinBoxCopyWith<$Res> {
  _$PinBoxCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PinBox
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? venueId = null,
    Object? venueName = null,
    Object? venuePhotoUrl = freezed,
    Object? category = null,
    Object? title = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? originalPrice = null,
    Object? pinboxPrice = null,
    Object? stockTotal = null,
    Object? stockRemaining = null,
    Object? pickupWindowStart = null,
    Object? pickupWindowEnd = null,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
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
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as VenueCategory,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
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
            originalPrice: null == originalPrice
                ? _value.originalPrice
                : originalPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            pinboxPrice: null == pinboxPrice
                ? _value.pinboxPrice
                : pinboxPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            stockTotal: null == stockTotal
                ? _value.stockTotal
                : stockTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            stockRemaining: null == stockRemaining
                ? _value.stockRemaining
                : stockRemaining // ignore: cast_nullable_to_non_nullable
                      as int,
            pickupWindowStart: null == pickupWindowStart
                ? _value.pickupWindowStart
                : pickupWindowStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            pickupWindowEnd: null == pickupWindowEnd
                ? _value.pickupWindowEnd
                : pickupWindowEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            reviewNote: freezed == reviewNote
                ? _value.reviewNote
                : reviewNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedBy: freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
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
abstract class _$$PinBoxImplCopyWith<$Res> implements $PinBoxCopyWith<$Res> {
  factory _$$PinBoxImplCopyWith(
    _$PinBoxImpl value,
    $Res Function(_$PinBoxImpl) then,
  ) = __$$PinBoxImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ownerId,
    String venueId,
    String venueName,
    String? venuePhotoUrl,
    @VenueCategoryConverter() VenueCategory category,
    String title,
    String description,
    String? imageUrl,
    double lat,
    double lng,
    String address,
    String? country,
    double originalPrice,
    double pinboxPrice,
    int stockTotal,
    int stockRemaining,
    @TimestampConverter() DateTime pickupWindowStart,
    @TimestampConverter() DateTime pickupWindowEnd,
    String status,
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class __$$PinBoxImplCopyWithImpl<$Res>
    extends _$PinBoxCopyWithImpl<$Res, _$PinBoxImpl>
    implements _$$PinBoxImplCopyWith<$Res> {
  __$$PinBoxImplCopyWithImpl(
    _$PinBoxImpl _value,
    $Res Function(_$PinBoxImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PinBox
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = null,
    Object? venueId = null,
    Object? venueName = null,
    Object? venuePhotoUrl = freezed,
    Object? category = null,
    Object? title = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? originalPrice = null,
    Object? pinboxPrice = null,
    Object? stockTotal = null,
    Object? stockRemaining = null,
    Object? pickupWindowStart = null,
    Object? pickupWindowEnd = null,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$PinBoxImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerId: null == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
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
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as VenueCategory,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
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
        originalPrice: null == originalPrice
            ? _value.originalPrice
            : originalPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        pinboxPrice: null == pinboxPrice
            ? _value.pinboxPrice
            : pinboxPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        stockTotal: null == stockTotal
            ? _value.stockTotal
            : stockTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        stockRemaining: null == stockRemaining
            ? _value.stockRemaining
            : stockRemaining // ignore: cast_nullable_to_non_nullable
                  as int,
        pickupWindowStart: null == pickupWindowStart
            ? _value.pickupWindowStart
            : pickupWindowStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        pickupWindowEnd: null == pickupWindowEnd
            ? _value.pickupWindowEnd
            : pickupWindowEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        reviewNote: freezed == reviewNote
            ? _value.reviewNote
            : reviewNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedBy: freezed == reviewedBy
            ? _value.reviewedBy
            : reviewedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
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
class _$PinBoxImpl extends _PinBox {
  const _$PinBoxImpl({
    required this.id,
    required this.ownerId,
    required this.venueId,
    required this.venueName,
    this.venuePhotoUrl,
    @VenueCategoryConverter() required this.category,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.lat,
    required this.lng,
    required this.address,
    this.country,
    required this.originalPrice,
    required this.pinboxPrice,
    required this.stockTotal,
    required this.stockRemaining,
    @TimestampConverter() required this.pickupWindowStart,
    @TimestampConverter() required this.pickupWindowEnd,
    this.status = 'pending',
    this.reviewNote,
    this.reviewedBy,
    @NullableTimestampConverter() this.reviewedAt,
    @TimestampConverter() required this.createdAt,
    @NullableTimestampConverter() this.updatedAt,
  }) : super._();

  factory _$PinBoxImpl.fromJson(Map<String, dynamic> json) =>
      _$$PinBoxImplFromJson(json);

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final String venueId;
  @override
  final String venueName;
  @override
  final String? venuePhotoUrl;
  @override
  @VenueCategoryConverter()
  final VenueCategory category;
  @override
  final String title;
  @override
  final String description;
  @override
  final String? imageUrl;
  @override
  final double lat;
  @override
  final double lng;
  @override
  final String address;
  @override
  final String? country;

  /// Menu/original value of the box's contents — struck through next
  /// to [pinboxPrice] on every card, same visual convention as the
  /// reference mockups.
  @override
  final double originalPrice;

  /// What the buyer actually pays — [discountPercent] is always
  /// derived from these two, never stored separately, so the two
  /// numbers can't silently drift.
  @override
  final double pinboxPrice;
  @override
  final int stockTotal;

  /// Client-visible cache of remaining stock — the SOURCE of truth is
  /// server-side (a Cloud Function transaction decrements this
  /// atomically on each successful order, see PinBox Faza 7's doc
  /// comment on why the non-transactional `availableSeats` pattern
  /// was deliberately NOT reused here). Locked from direct client
  /// writes in firestore.rules.
  @override
  final int stockRemaining;
  @override
  @TimestampConverter()
  final DateTime pickupWindowStart;
  @override
  @TimestampConverter()
  final DateTime pickupWindowEnd;

  /// 'pending' | 'active' | 'soldOut' | 'expired' | 'rejected' |
  /// 'needs_revision' — same moderation lifecycle shape as
  /// [Offer.status]/[Venue.status]; only the admin panel's Server
  /// Actions may move it off 'pending'. Unlike Offer/Venue there's no
  /// `revisionDeadline` field — a PinBox listing has no upfront fee
  /// to protect with an auto-reject/refund clock, so 'needs_revision'
  /// just waits on the owner's own resubmission via `resubmitPinBox`.
  @override
  @JsonKey()
  final String status;
  @override
  final String? reviewNote;
  @override
  final String? reviewedBy;
  @override
  @NullableTimestampConverter()
  final DateTime? reviewedAt;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @NullableTimestampConverter()
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'PinBox(id: $id, ownerId: $ownerId, venueId: $venueId, venueName: $venueName, venuePhotoUrl: $venuePhotoUrl, category: $category, title: $title, description: $description, imageUrl: $imageUrl, lat: $lat, lng: $lng, address: $address, country: $country, originalPrice: $originalPrice, pinboxPrice: $pinboxPrice, stockTotal: $stockTotal, stockRemaining: $stockRemaining, pickupWindowStart: $pickupWindowStart, pickupWindowEnd: $pickupWindowEnd, status: $status, reviewNote: $reviewNote, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PinBoxImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.venueName, venueName) ||
                other.venueName == venueName) &&
            (identical(other.venuePhotoUrl, venuePhotoUrl) ||
                other.venuePhotoUrl == venuePhotoUrl) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.originalPrice, originalPrice) ||
                other.originalPrice == originalPrice) &&
            (identical(other.pinboxPrice, pinboxPrice) ||
                other.pinboxPrice == pinboxPrice) &&
            (identical(other.stockTotal, stockTotal) ||
                other.stockTotal == stockTotal) &&
            (identical(other.stockRemaining, stockRemaining) ||
                other.stockRemaining == stockRemaining) &&
            (identical(other.pickupWindowStart, pickupWindowStart) ||
                other.pickupWindowStart == pickupWindowStart) &&
            (identical(other.pickupWindowEnd, pickupWindowEnd) ||
                other.pickupWindowEnd == pickupWindowEnd) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewNote, reviewNote) ||
                other.reviewNote == reviewNote) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    ownerId,
    venueId,
    venueName,
    venuePhotoUrl,
    category,
    title,
    description,
    imageUrl,
    lat,
    lng,
    address,
    country,
    originalPrice,
    pinboxPrice,
    stockTotal,
    stockRemaining,
    pickupWindowStart,
    pickupWindowEnd,
    status,
    reviewNote,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of PinBox
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PinBoxImplCopyWith<_$PinBoxImpl> get copyWith =>
      __$$PinBoxImplCopyWithImpl<_$PinBoxImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PinBoxImplToJson(this);
  }
}

abstract class _PinBox extends PinBox {
  const factory _PinBox({
    required final String id,
    required final String ownerId,
    required final String venueId,
    required final String venueName,
    final String? venuePhotoUrl,
    @VenueCategoryConverter() required final VenueCategory category,
    required final String title,
    required final String description,
    final String? imageUrl,
    required final double lat,
    required final double lng,
    required final String address,
    final String? country,
    required final double originalPrice,
    required final double pinboxPrice,
    required final int stockTotal,
    required final int stockRemaining,
    @TimestampConverter() required final DateTime pickupWindowStart,
    @TimestampConverter() required final DateTime pickupWindowEnd,
    final String status,
    final String? reviewNote,
    final String? reviewedBy,
    @NullableTimestampConverter() final DateTime? reviewedAt,
    @TimestampConverter() required final DateTime createdAt,
    @NullableTimestampConverter() final DateTime? updatedAt,
  }) = _$PinBoxImpl;
  const _PinBox._() : super._();

  factory _PinBox.fromJson(Map<String, dynamic> json) = _$PinBoxImpl.fromJson;

  @override
  String get id;
  @override
  String get ownerId;
  @override
  String get venueId;
  @override
  String get venueName;
  @override
  String? get venuePhotoUrl;
  @override
  @VenueCategoryConverter()
  VenueCategory get category;
  @override
  String get title;
  @override
  String get description;
  @override
  String? get imageUrl;
  @override
  double get lat;
  @override
  double get lng;
  @override
  String get address;
  @override
  String? get country;

  /// Menu/original value of the box's contents — struck through next
  /// to [pinboxPrice] on every card, same visual convention as the
  /// reference mockups.
  @override
  double get originalPrice;

  /// What the buyer actually pays — [discountPercent] is always
  /// derived from these two, never stored separately, so the two
  /// numbers can't silently drift.
  @override
  double get pinboxPrice;
  @override
  int get stockTotal;

  /// Client-visible cache of remaining stock — the SOURCE of truth is
  /// server-side (a Cloud Function transaction decrements this
  /// atomically on each successful order, see PinBox Faza 7's doc
  /// comment on why the non-transactional `availableSeats` pattern
  /// was deliberately NOT reused here). Locked from direct client
  /// writes in firestore.rules.
  @override
  int get stockRemaining;
  @override
  @TimestampConverter()
  DateTime get pickupWindowStart;
  @override
  @TimestampConverter()
  DateTime get pickupWindowEnd;

  /// 'pending' | 'active' | 'soldOut' | 'expired' | 'rejected' |
  /// 'needs_revision' — same moderation lifecycle shape as
  /// [Offer.status]/[Venue.status]; only the admin panel's Server
  /// Actions may move it off 'pending'. Unlike Offer/Venue there's no
  /// `revisionDeadline` field — a PinBox listing has no upfront fee
  /// to protect with an auto-reject/refund clock, so 'needs_revision'
  /// just waits on the owner's own resubmission via `resubmitPinBox`.
  @override
  String get status;
  @override
  String? get reviewNote;
  @override
  String? get reviewedBy;
  @override
  @NullableTimestampConverter()
  DateTime? get reviewedAt;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @NullableTimestampConverter()
  DateTime? get updatedAt;

  /// Create a copy of PinBox
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PinBoxImplCopyWith<_$PinBoxImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
