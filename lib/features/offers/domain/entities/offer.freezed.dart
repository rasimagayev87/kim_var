// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Offer _$OfferFromJson(Map<String, dynamic> json) {
  return _Offer.fromJson(json);
}

/// @nodoc
mixin _$Offer {
  String get id => throw _privateConstructorUsedError;
  String get ownerId => throw _privateConstructorUsedError;
  String get venueId => throw _privateConstructorUsedError;
  String get venueName => throw _privateConstructorUsedError;
  String? get venuePhotoUrl => throw _privateConstructorUsedError;
  @VenueCategoryConverter()
  VenueCategory get category => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @OfferTypeConverter()
  OfferType get offerType => throw _privateConstructorUsedError;

  /// Percentage (0-100) for [OfferType.discount], AZN amount for
  /// [OfferType.fixedPrice]. Null for [OfferType.gift]/
  /// [OfferType.buyOneGetOne].
  double? get discountValue => throw _privateConstructorUsedError;
  double get lat => throw _privateConstructorUsedError;
  double get lng => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;

  /// Denormalized from the venue's own reverse-geocoded country —
  /// powers "Ölkə üzrə", the exact same radius mode Venues/İnsanlar
  /// already support. Null when the venue itself has no resolved
  /// country.
  String? get country => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get startDate => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get endDate => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Optional terms/eligibility text — free-form, shown as-is.
  String? get terms => throw _privateConstructorUsedError;

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected' — same
  /// moderation lifecycle as [Venue.status], including the
  /// firestore.rules restriction that only the admin panel's Server
  /// Actions may change it.
  String get status => throw _privateConstructorUsedError;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected'. Null otherwise.
  String? get reviewNote => throw _privateConstructorUsedError;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  String? get reviewedBy => throw _privateConstructorUsedError;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @NullableTimestampConverter()
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Set by the owner via `OfferController.boostOffer` (Offer Details
  /// → the owner's own offer → the 3-dot menu, replacing the heart
  /// every other viewer sees there). While in the future, the offer
  /// sorts ahead of non-boosted ones in `nearbyOffersProvider` —
  /// unlike venues (governed purely by user likes/votes, see
  /// `Venue`'s own doc comments), a real time-boxed paid boost is the
  /// actual product decision for offers specifically.
  @NullableTimestampConverter()
  DateTime? get boostedUntil => throw _privateConstructorUsedError;

  /// Only set for [OfferType.happyHour] — the daily window (e.g.
  /// 15:00–17:00) the discount is active. Null for every other type.
  @ActiveHoursConverter()
  ActiveHours? get activeHours => throw _privateConstructorUsedError;

  /// Only meaningful for [OfferType.happyHour] — 'mon'..'sun' keys the
  /// window runs on. The create form defaults every day checked, so
  /// this is only ever empty for a type other than [happyHour].
  List<String> get activeDays => throw _privateConstructorUsedError;

  /// Only set for [OfferType.birthday] — the `birthdayMatches/{id}`
  /// doc this offer was created from. Null for every other type.
  String? get birthdayMatchId => throw _privateConstructorUsedError;

  /// Only meaningful for [OfferType.birthday] — the specific uids this
  /// offer is for, copied from the matching `birthdayMatches` doc
  /// at creation time (so it stays correct even if that doc is later
  /// pruned/changes). Empty for every other type. `nearbyOffersProvider`
  /// and every other "everyone" offer stream filters a [birthday]
  /// offer down to only viewers whose uid is in this list — see
  /// `OfferRepository`'s query doc comments.
  List<String> get targetUserIds => throw _privateConstructorUsedError;

  /// Only meaningful for [OfferType.birthday] — the owner's optional
  /// note to the birthday user(s) (max 100 chars, enforced by the
  /// create form). Null when left blank.
  String? get personalMessage => throw _privateConstructorUsedError;

  /// Serializes this Offer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Offer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OfferCopyWith<Offer> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OfferCopyWith<$Res> {
  factory $OfferCopyWith(Offer value, $Res Function(Offer) then) =
      _$OfferCopyWithImpl<$Res, Offer>;
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
    @OfferTypeConverter() OfferType offerType,
    double? discountValue,
    double lat,
    double lng,
    String address,
    String? country,
    @TimestampConverter() DateTime startDate,
    @TimestampConverter() DateTime endDate,
    String? imageUrl,
    String? terms,
    String status,
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
    @NullableTimestampConverter() DateTime? boostedUntil,
    @ActiveHoursConverter() ActiveHours? activeHours,
    List<String> activeDays,
    String? birthdayMatchId,
    List<String> targetUserIds,
    String? personalMessage,
  });
}

/// @nodoc
class _$OfferCopyWithImpl<$Res, $Val extends Offer>
    implements $OfferCopyWith<$Res> {
  _$OfferCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Offer
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
    Object? offerType = null,
    Object? discountValue = freezed,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? imageUrl = freezed,
    Object? terms = freezed,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? boostedUntil = freezed,
    Object? activeHours = freezed,
    Object? activeDays = null,
    Object? birthdayMatchId = freezed,
    Object? targetUserIds = null,
    Object? personalMessage = freezed,
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
            offerType: null == offerType
                ? _value.offerType
                : offerType // ignore: cast_nullable_to_non_nullable
                      as OfferType,
            discountValue: freezed == discountValue
                ? _value.discountValue
                : discountValue // ignore: cast_nullable_to_non_nullable
                      as double?,
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
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            terms: freezed == terms
                ? _value.terms
                : terms // ignore: cast_nullable_to_non_nullable
                      as String?,
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
            boostedUntil: freezed == boostedUntil
                ? _value.boostedUntil
                : boostedUntil // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            activeHours: freezed == activeHours
                ? _value.activeHours
                : activeHours // ignore: cast_nullable_to_non_nullable
                      as ActiveHours?,
            activeDays: null == activeDays
                ? _value.activeDays
                : activeDays // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            birthdayMatchId: freezed == birthdayMatchId
                ? _value.birthdayMatchId
                : birthdayMatchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetUserIds: null == targetUserIds
                ? _value.targetUserIds
                : targetUserIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            personalMessage: freezed == personalMessage
                ? _value.personalMessage
                : personalMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OfferImplCopyWith<$Res> implements $OfferCopyWith<$Res> {
  factory _$$OfferImplCopyWith(
    _$OfferImpl value,
    $Res Function(_$OfferImpl) then,
  ) = __$$OfferImplCopyWithImpl<$Res>;
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
    @OfferTypeConverter() OfferType offerType,
    double? discountValue,
    double lat,
    double lng,
    String address,
    String? country,
    @TimestampConverter() DateTime startDate,
    @TimestampConverter() DateTime endDate,
    String? imageUrl,
    String? terms,
    String status,
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
    @NullableTimestampConverter() DateTime? boostedUntil,
    @ActiveHoursConverter() ActiveHours? activeHours,
    List<String> activeDays,
    String? birthdayMatchId,
    List<String> targetUserIds,
    String? personalMessage,
  });
}

/// @nodoc
class __$$OfferImplCopyWithImpl<$Res>
    extends _$OfferCopyWithImpl<$Res, _$OfferImpl>
    implements _$$OfferImplCopyWith<$Res> {
  __$$OfferImplCopyWithImpl(
    _$OfferImpl _value,
    $Res Function(_$OfferImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Offer
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
    Object? offerType = null,
    Object? discountValue = freezed,
    Object? lat = null,
    Object? lng = null,
    Object? address = null,
    Object? country = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? imageUrl = freezed,
    Object? terms = freezed,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? boostedUntil = freezed,
    Object? activeHours = freezed,
    Object? activeDays = null,
    Object? birthdayMatchId = freezed,
    Object? targetUserIds = null,
    Object? personalMessage = freezed,
  }) {
    return _then(
      _$OfferImpl(
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
        offerType: null == offerType
            ? _value.offerType
            : offerType // ignore: cast_nullable_to_non_nullable
                  as OfferType,
        discountValue: freezed == discountValue
            ? _value.discountValue
            : discountValue // ignore: cast_nullable_to_non_nullable
                  as double?,
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
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        terms: freezed == terms
            ? _value.terms
            : terms // ignore: cast_nullable_to_non_nullable
                  as String?,
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
        boostedUntil: freezed == boostedUntil
            ? _value.boostedUntil
            : boostedUntil // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        activeHours: freezed == activeHours
            ? _value.activeHours
            : activeHours // ignore: cast_nullable_to_non_nullable
                  as ActiveHours?,
        activeDays: null == activeDays
            ? _value._activeDays
            : activeDays // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        birthdayMatchId: freezed == birthdayMatchId
            ? _value.birthdayMatchId
            : birthdayMatchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetUserIds: null == targetUserIds
            ? _value._targetUserIds
            : targetUserIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        personalMessage: freezed == personalMessage
            ? _value.personalMessage
            : personalMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OfferImpl extends _Offer {
  const _$OfferImpl({
    required this.id,
    required this.ownerId,
    required this.venueId,
    required this.venueName,
    this.venuePhotoUrl,
    @VenueCategoryConverter() required this.category,
    required this.title,
    required this.description,
    @OfferTypeConverter() required this.offerType,
    this.discountValue,
    required this.lat,
    required this.lng,
    required this.address,
    this.country,
    @TimestampConverter() required this.startDate,
    @TimestampConverter() required this.endDate,
    this.imageUrl,
    this.terms,
    this.status = 'pending',
    this.reviewNote,
    this.reviewedBy,
    @NullableTimestampConverter() this.reviewedAt,
    @TimestampConverter() required this.createdAt,
    @NullableTimestampConverter() this.updatedAt,
    @NullableTimestampConverter() this.boostedUntil,
    @ActiveHoursConverter() this.activeHours,
    final List<String> activeDays = const <String>[],
    this.birthdayMatchId,
    final List<String> targetUserIds = const <String>[],
    this.personalMessage,
  }) : _activeDays = activeDays,
       _targetUserIds = targetUserIds,
       super._();

  factory _$OfferImpl.fromJson(Map<String, dynamic> json) =>
      _$$OfferImplFromJson(json);

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
  @OfferTypeConverter()
  final OfferType offerType;

  /// Percentage (0-100) for [OfferType.discount], AZN amount for
  /// [OfferType.fixedPrice]. Null for [OfferType.gift]/
  /// [OfferType.buyOneGetOne].
  @override
  final double? discountValue;
  @override
  final double lat;
  @override
  final double lng;
  @override
  final String address;

  /// Denormalized from the venue's own reverse-geocoded country —
  /// powers "Ölkə üzrə", the exact same radius mode Venues/İnsanlar
  /// already support. Null when the venue itself has no resolved
  /// country.
  @override
  final String? country;
  @override
  @TimestampConverter()
  final DateTime startDate;
  @override
  @TimestampConverter()
  final DateTime endDate;
  @override
  final String? imageUrl;

  /// Optional terms/eligibility text — free-form, shown as-is.
  @override
  final String? terms;

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected' — same
  /// moderation lifecycle as [Venue.status], including the
  /// firestore.rules restriction that only the admin panel's Server
  /// Actions may change it.
  @override
  @JsonKey()
  final String status;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected'. Null otherwise.
  @override
  final String? reviewNote;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  @override
  final String? reviewedBy;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @override
  @NullableTimestampConverter()
  final DateTime? reviewedAt;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @NullableTimestampConverter()
  final DateTime? updatedAt;

  /// Set by the owner via `OfferController.boostOffer` (Offer Details
  /// → the owner's own offer → the 3-dot menu, replacing the heart
  /// every other viewer sees there). While in the future, the offer
  /// sorts ahead of non-boosted ones in `nearbyOffersProvider` —
  /// unlike venues (governed purely by user likes/votes, see
  /// `Venue`'s own doc comments), a real time-boxed paid boost is the
  /// actual product decision for offers specifically.
  @override
  @NullableTimestampConverter()
  final DateTime? boostedUntil;

  /// Only set for [OfferType.happyHour] — the daily window (e.g.
  /// 15:00–17:00) the discount is active. Null for every other type.
  @override
  @ActiveHoursConverter()
  final ActiveHours? activeHours;

  /// Only meaningful for [OfferType.happyHour] — 'mon'..'sun' keys the
  /// window runs on. The create form defaults every day checked, so
  /// this is only ever empty for a type other than [happyHour].
  final List<String> _activeDays;

  /// Only meaningful for [OfferType.happyHour] — 'mon'..'sun' keys the
  /// window runs on. The create form defaults every day checked, so
  /// this is only ever empty for a type other than [happyHour].
  @override
  @JsonKey()
  List<String> get activeDays {
    if (_activeDays is EqualUnmodifiableListView) return _activeDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeDays);
  }

  /// Only set for [OfferType.birthday] — the `birthdayMatches/{id}`
  /// doc this offer was created from. Null for every other type.
  @override
  final String? birthdayMatchId;

  /// Only meaningful for [OfferType.birthday] — the specific uids this
  /// offer is for, copied from the matching `birthdayMatches` doc
  /// at creation time (so it stays correct even if that doc is later
  /// pruned/changes). Empty for every other type. `nearbyOffersProvider`
  /// and every other "everyone" offer stream filters a [birthday]
  /// offer down to only viewers whose uid is in this list — see
  /// `OfferRepository`'s query doc comments.
  final List<String> _targetUserIds;

  /// Only meaningful for [OfferType.birthday] — the specific uids this
  /// offer is for, copied from the matching `birthdayMatches` doc
  /// at creation time (so it stays correct even if that doc is later
  /// pruned/changes). Empty for every other type. `nearbyOffersProvider`
  /// and every other "everyone" offer stream filters a [birthday]
  /// offer down to only viewers whose uid is in this list — see
  /// `OfferRepository`'s query doc comments.
  @override
  @JsonKey()
  List<String> get targetUserIds {
    if (_targetUserIds is EqualUnmodifiableListView) return _targetUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetUserIds);
  }

  /// Only meaningful for [OfferType.birthday] — the owner's optional
  /// note to the birthday user(s) (max 100 chars, enforced by the
  /// create form). Null when left blank.
  @override
  final String? personalMessage;

  @override
  String toString() {
    return 'Offer(id: $id, ownerId: $ownerId, venueId: $venueId, venueName: $venueName, venuePhotoUrl: $venuePhotoUrl, category: $category, title: $title, description: $description, offerType: $offerType, discountValue: $discountValue, lat: $lat, lng: $lng, address: $address, country: $country, startDate: $startDate, endDate: $endDate, imageUrl: $imageUrl, terms: $terms, status: $status, reviewNote: $reviewNote, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, createdAt: $createdAt, updatedAt: $updatedAt, boostedUntil: $boostedUntil, activeHours: $activeHours, activeDays: $activeDays, birthdayMatchId: $birthdayMatchId, targetUserIds: $targetUserIds, personalMessage: $personalMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OfferImpl &&
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
            (identical(other.offerType, offerType) ||
                other.offerType == offerType) &&
            (identical(other.discountValue, discountValue) ||
                other.discountValue == discountValue) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.terms, terms) || other.terms == terms) &&
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
                other.updatedAt == updatedAt) &&
            (identical(other.boostedUntil, boostedUntil) ||
                other.boostedUntil == boostedUntil) &&
            (identical(other.activeHours, activeHours) ||
                other.activeHours == activeHours) &&
            const DeepCollectionEquality().equals(
              other._activeDays,
              _activeDays,
            ) &&
            (identical(other.birthdayMatchId, birthdayMatchId) ||
                other.birthdayMatchId == birthdayMatchId) &&
            const DeepCollectionEquality().equals(
              other._targetUserIds,
              _targetUserIds,
            ) &&
            (identical(other.personalMessage, personalMessage) ||
                other.personalMessage == personalMessage));
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
    offerType,
    discountValue,
    lat,
    lng,
    address,
    country,
    startDate,
    endDate,
    imageUrl,
    terms,
    status,
    reviewNote,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
    boostedUntil,
    activeHours,
    const DeepCollectionEquality().hash(_activeDays),
    birthdayMatchId,
    const DeepCollectionEquality().hash(_targetUserIds),
    personalMessage,
  ]);

  /// Create a copy of Offer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OfferImplCopyWith<_$OfferImpl> get copyWith =>
      __$$OfferImplCopyWithImpl<_$OfferImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OfferImplToJson(this);
  }
}

abstract class _Offer extends Offer {
  const factory _Offer({
    required final String id,
    required final String ownerId,
    required final String venueId,
    required final String venueName,
    final String? venuePhotoUrl,
    @VenueCategoryConverter() required final VenueCategory category,
    required final String title,
    required final String description,
    @OfferTypeConverter() required final OfferType offerType,
    final double? discountValue,
    required final double lat,
    required final double lng,
    required final String address,
    final String? country,
    @TimestampConverter() required final DateTime startDate,
    @TimestampConverter() required final DateTime endDate,
    final String? imageUrl,
    final String? terms,
    final String status,
    final String? reviewNote,
    final String? reviewedBy,
    @NullableTimestampConverter() final DateTime? reviewedAt,
    @TimestampConverter() required final DateTime createdAt,
    @NullableTimestampConverter() final DateTime? updatedAt,
    @NullableTimestampConverter() final DateTime? boostedUntil,
    @ActiveHoursConverter() final ActiveHours? activeHours,
    final List<String> activeDays,
    final String? birthdayMatchId,
    final List<String> targetUserIds,
    final String? personalMessage,
  }) = _$OfferImpl;
  const _Offer._() : super._();

  factory _Offer.fromJson(Map<String, dynamic> json) = _$OfferImpl.fromJson;

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
  @OfferTypeConverter()
  OfferType get offerType;

  /// Percentage (0-100) for [OfferType.discount], AZN amount for
  /// [OfferType.fixedPrice]. Null for [OfferType.gift]/
  /// [OfferType.buyOneGetOne].
  @override
  double? get discountValue;
  @override
  double get lat;
  @override
  double get lng;
  @override
  String get address;

  /// Denormalized from the venue's own reverse-geocoded country —
  /// powers "Ölkə üzrə", the exact same radius mode Venues/İnsanlar
  /// already support. Null when the venue itself has no resolved
  /// country.
  @override
  String? get country;
  @override
  @TimestampConverter()
  DateTime get startDate;
  @override
  @TimestampConverter()
  DateTime get endDate;
  @override
  String? get imageUrl;

  /// Optional terms/eligibility text — free-form, shown as-is.
  @override
  String? get terms;

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected' — same
  /// moderation lifecycle as [Venue.status], including the
  /// firestore.rules restriction that only the admin panel's Server
  /// Actions may change it.
  @override
  String get status;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected'. Null otherwise.
  @override
  String? get reviewNote;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  @override
  String? get reviewedBy;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @override
  @NullableTimestampConverter()
  DateTime? get reviewedAt;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @NullableTimestampConverter()
  DateTime? get updatedAt;

  /// Set by the owner via `OfferController.boostOffer` (Offer Details
  /// → the owner's own offer → the 3-dot menu, replacing the heart
  /// every other viewer sees there). While in the future, the offer
  /// sorts ahead of non-boosted ones in `nearbyOffersProvider` —
  /// unlike venues (governed purely by user likes/votes, see
  /// `Venue`'s own doc comments), a real time-boxed paid boost is the
  /// actual product decision for offers specifically.
  @override
  @NullableTimestampConverter()
  DateTime? get boostedUntil;

  /// Only set for [OfferType.happyHour] — the daily window (e.g.
  /// 15:00–17:00) the discount is active. Null for every other type.
  @override
  @ActiveHoursConverter()
  ActiveHours? get activeHours;

  /// Only meaningful for [OfferType.happyHour] — 'mon'..'sun' keys the
  /// window runs on. The create form defaults every day checked, so
  /// this is only ever empty for a type other than [happyHour].
  @override
  List<String> get activeDays;

  /// Only set for [OfferType.birthday] — the `birthdayMatches/{id}`
  /// doc this offer was created from. Null for every other type.
  @override
  String? get birthdayMatchId;

  /// Only meaningful for [OfferType.birthday] — the specific uids this
  /// offer is for, copied from the matching `birthdayMatches` doc
  /// at creation time (so it stays correct even if that doc is later
  /// pruned/changes). Empty for every other type. `nearbyOffersProvider`
  /// and every other "everyone" offer stream filters a [birthday]
  /// offer down to only viewers whose uid is in this list — see
  /// `OfferRepository`'s query doc comments.
  @override
  List<String> get targetUserIds;

  /// Only meaningful for [OfferType.birthday] — the owner's optional
  /// note to the birthday user(s) (max 100 chars, enforced by the
  /// create form). Null when left blank.
  @override
  String? get personalMessage;

  /// Create a copy of Offer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OfferImplCopyWith<_$OfferImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
