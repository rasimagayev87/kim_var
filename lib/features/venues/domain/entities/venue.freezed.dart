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

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected'. New
  /// venues start 'pending' and stay invisible to discovery until an
  /// admin/moderator approves them — see firestore.rules, which
  /// blocks the owner from writing this field directly; only the
  /// admin panel's Server Actions (Admin SDK) may change it.
  String get status => throw _privateConstructorUsedError;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected' — shown to the owner as the
  /// reason. Null otherwise.
  String? get reviewNote => throw _privateConstructorUsedError;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  String? get reviewedBy => throw _privateConstructorUsedError;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @NullableTimestampConverter()
  DateTime? get reviewedAt => throw _privateConstructorUsedError;

  /// The `payments/{paymentId}` doc backing this venue's most recent
  /// subscription charge — see `PaymentRecord`/`functions/src/
  /// index.ts`'s payment-refund state machine. Null on venues created
  /// before this field existed.
  String? get paymentId => throw _privateConstructorUsedError;

  /// When the category-based listing fee (see `_venueListingFeeFor`)
  /// next renews — set at creation to `createdAt + 30 days`, then
  /// pushed forward another 30 days each cycle by
  /// `renewVenueSubscriptions` (scheduled Cloud Function,
  /// functions/src/index.ts), which also writes the corresponding
  /// `payments/{id}` doc (`type: 'venue_subscription'`) for that
  /// cycle. Grant-of-trust like [paymentId] — only that Cloud
  /// Function may move it forward, never the owner's own client write
  /// (see firestore.rules). Null on venues created before this field
  /// existed — `renewVenueSubscriptions` treats a null the same as an
  /// overdue date so those venues enter the cycle on its next run.
  @NullableTimestampConverter()
  DateTime? get subscriptionRenewsAt => throw _privateConstructorUsedError;

  /// True for one of the first 1000 venues ever approved — see
  /// `assignFoundingVenueIfEligible` (Cloud Function, functions/src/
  /// index.ts), which sets this (with [freeOffersUsed]/
  /// [freeOfferWindowEnd]) the moment [status] first reaches
  /// 'approved', never at raw signup. Grant-of-trust — the owner can't
  /// self-grant this (see firestore.rules). Drives the "Bu təklif
  /// pulsuzdur" free-quota check in `submitOffer`/the offer create
  /// form; `false` (the default) for every venue outside the first
  /// 1000 and for any venue created before this field existed.
  bool get isFoundingVenue => throw _privateConstructorUsedError;

  /// How many of [isFoundingVenue]'s 5 free offer placements this
  /// venue has used — incremented atomically inside `submitOffer`'s
  /// own transaction each time a free placement is granted, never by
  /// a direct client write (see firestore.rules). Meaningless when
  /// [isFoundingVenue] is false.
  int get freeOffersUsed => throw _privateConstructorUsedError;

  /// The 1-month window [isFoundingVenue]'s free quota is valid
  /// within — set once, alongside [isFoundingVenue], to
  /// "first approval + 30 days". Null for a non-founding venue.
  @NullableTimestampConverter()
  DateTime? get freeOfferWindowEnd => throw _privateConstructorUsedError;

  /// True from the moment this venue's FIRST subscription payment
  /// clears (`applyPaymentOutcome`, functions/src/index.ts) until the
  /// owner dismisses the resulting confirmation card on
  /// `MyVenuesScreen` (`dismissFirstPaymentAnnouncement`). Read
  /// alongside [isFoundingVenue]/[subscriptionRenewsAt] at render
  /// time, not a frozen snapshot — see this field's own producer
  /// comment for why.
  bool get firstPaymentAnnouncementPending =>
      throw _privateConstructorUsedError;

  /// Only set while [status] is 'needs_revision' — the owner has this
  /// long to resubmit before `expireVenueRevisionDeadlines` (scheduled
  /// Cloud Function) auto-rejects the venue and refunds the payment.
  /// Cleared back to null by `resubmitVenue` on resubmission, and by
  /// the admin panel whenever [status] moves away from
  /// 'needs_revision'. Grant-of-trust like [status] itself — the owner
  /// can't extend their own deadline (see firestore.rules).
  @NullableTimestampConverter()
  DateTime? get revisionDeadline => throw _privateConstructorUsedError;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  bool get verified => throw _privateConstructorUsedError;

  /// Denormalized count of `venues/{id}/likes` docs — written ONLY by
  /// the `onVenueLikeCreated`/`onVenueLikeDeleted` Cloud Function
  /// triggers (see functions/src/index.ts), never directly by the
  /// client (firestore.rules blocks that) so it can't be gamed by a
  /// raw Firestore write.
  int get likeCount => throw _privateConstructorUsedError;

  /// 0-5, one decimal — derived purely from [likeCount] by the same
  /// triggers that maintain it (base 3.0 + 0.1 per 5 likes, capped at
  /// 5.0). Never set directly by the client.
  double get rating => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Owner-provided WhatsApp/Instagram/TikTok — null (not an empty
  /// object) when the owner filled in none of the three, so
  /// `VenueProfileScreen` can tell "no social links at all" apart
  /// from "links exist but this specific one is unset" with one check.
  @VenueSocialLinksConverter()
  VenueSocialLinks? get socialLinks => throw _privateConstructorUsedError;

  /// 'distance' | 'country' | 'world' — same 3 modes as Discover's own
  /// `DiscoverRadiusSelection`, just persisted here since the owner
  /// picks one and it stays fixed, where Discover's version is
  /// transient per-viewer session state, never saved.
  String get audienceRadiusMode => throw _privateConstructorUsedError;

  /// Only meaningful when [audienceRadiusMode] is 'distance' — radius
  /// (km) the owner-only "live audience" counter on
  /// [VenueProfileScreen] scans around [lat]/[lng] for recently-active
  /// `users` docs — see `location_providers.dart`'s
  /// `venueAudienceCountProvider`. Owner-editable from the create/edit
  /// form (same option set as Discover's own radius picker); defaults
  /// to 1km since venues have no other stored radius to default from.
  double get audienceRadiusKm => throw _privateConstructorUsedError;

  /// Set only by a future paid-upgrade flow (never by the owner's own
  /// create/edit form — no client write path exists for this yet).
  /// Premium venues sort first within their radius in
  /// [nearbyVenuesProvider] and get a crown badge next to their name.
  bool get isPremium => throw _privateConstructorUsedError;

  /// When [isPremium] most recently turned on, from the admin
  /// panel's toggle (`admin-panel/src/lib/actions/venues.ts`) — the
  /// only write path for this field. Re-toggling premium on again
  /// after turning it off resets this to the new grant time, since
  /// nothing tracks premium history beyond "currently on since X".
  /// Shown on `VenuePremiumInfoScreen`; `null` on venues predating
  /// this field.
  @NullableTimestampConverter()
  DateTime? get premiumSince => throw _privateConstructorUsedError;

  /// Whether `computeBirthdayMatches` (the daily birthday-offer
  /// matching Cloud Function) considers this venue at all — defaults
  /// to `category`'s membership in [kBirthdayEligibleVenueCategories]
  /// at creation time, owner-editable afterward from the create/edit
  /// form ONLY for categories in that set (every other category
  /// never shows the toggle, so this just stays `false` for them).
  bool get birthdayNotificationsEnabled => throw _privateConstructorUsedError;

  /// Owner-set "current free seats" count (0-50), edited from the
  /// standalone seat-count sheet on `MyVenuesScreen` (NOT the
  /// create/edit form — this is meant for frequent, lightweight
  /// updates, not a full re-submit). Null means the owner has never
  /// turned this feature on — [SeatAvailabilityCard] on
  /// `VenueProfileScreen` renders nothing at all in that case, rather
  /// than showing a misleading "0 seats".
  int? get availableSeats => throw _privateConstructorUsedError;

  /// When [availableSeats] was last written — always set together
  /// with it (`FieldValue.serverTimestamp()`), null exactly when
  /// [availableSeats] is null. Powers the "X dəq əvvəl yeniləndi"
  /// caption under the card.
  @NullableTimestampConverter()
  DateTime? get seatsUpdatedAt => throw _privateConstructorUsedError;

  /// Owner's "Növbəni aktivləşdir/söndür" toggle for the walk-in
  /// waitlist feature (`venues/{id}/waitlist`) — false hides the
  /// "Sıraya yaz" button on `VenueProfileScreen`, but never affects
  /// entries already in the queue (they still see their own status
  /// and can still be called/seated normally).
  bool get waitlistEnabled => throw _privateConstructorUsedError;

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
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    String? paymentId,
    @NullableTimestampConverter() DateTime? subscriptionRenewsAt,
    bool isFoundingVenue,
    int freeOffersUsed,
    @NullableTimestampConverter() DateTime? freeOfferWindowEnd,
    bool firstPaymentAnnouncementPending,
    @NullableTimestampConverter() DateTime? revisionDeadline,
    bool verified,
    int likeCount,
    double rating,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
    @VenueSocialLinksConverter() VenueSocialLinks? socialLinks,
    String audienceRadiusMode,
    double audienceRadiusKm,
    bool isPremium,
    @NullableTimestampConverter() DateTime? premiumSince,
    bool birthdayNotificationsEnabled,
    int? availableSeats,
    @NullableTimestampConverter() DateTime? seatsUpdatedAt,
    bool waitlistEnabled,
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
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? paymentId = freezed,
    Object? subscriptionRenewsAt = freezed,
    Object? isFoundingVenue = null,
    Object? freeOffersUsed = null,
    Object? freeOfferWindowEnd = freezed,
    Object? firstPaymentAnnouncementPending = null,
    Object? revisionDeadline = freezed,
    Object? verified = null,
    Object? likeCount = null,
    Object? rating = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? socialLinks = freezed,
    Object? audienceRadiusMode = null,
    Object? audienceRadiusKm = null,
    Object? isPremium = null,
    Object? premiumSince = freezed,
    Object? birthdayNotificationsEnabled = null,
    Object? availableSeats = freezed,
    Object? seatsUpdatedAt = freezed,
    Object? waitlistEnabled = null,
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
            paymentId: freezed == paymentId
                ? _value.paymentId
                : paymentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            subscriptionRenewsAt: freezed == subscriptionRenewsAt
                ? _value.subscriptionRenewsAt
                : subscriptionRenewsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isFoundingVenue: null == isFoundingVenue
                ? _value.isFoundingVenue
                : isFoundingVenue // ignore: cast_nullable_to_non_nullable
                      as bool,
            freeOffersUsed: null == freeOffersUsed
                ? _value.freeOffersUsed
                : freeOffersUsed // ignore: cast_nullable_to_non_nullable
                      as int,
            freeOfferWindowEnd: freezed == freeOfferWindowEnd
                ? _value.freeOfferWindowEnd
                : freeOfferWindowEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            firstPaymentAnnouncementPending:
                null == firstPaymentAnnouncementPending
                ? _value.firstPaymentAnnouncementPending
                : firstPaymentAnnouncementPending // ignore: cast_nullable_to_non_nullable
                      as bool,
            revisionDeadline: freezed == revisionDeadline
                ? _value.revisionDeadline
                : revisionDeadline // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            verified: null == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool,
            likeCount: null == likeCount
                ? _value.likeCount
                : likeCount // ignore: cast_nullable_to_non_nullable
                      as int,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            socialLinks: freezed == socialLinks
                ? _value.socialLinks
                : socialLinks // ignore: cast_nullable_to_non_nullable
                      as VenueSocialLinks?,
            audienceRadiusMode: null == audienceRadiusMode
                ? _value.audienceRadiusMode
                : audienceRadiusMode // ignore: cast_nullable_to_non_nullable
                      as String,
            audienceRadiusKm: null == audienceRadiusKm
                ? _value.audienceRadiusKm
                : audienceRadiusKm // ignore: cast_nullable_to_non_nullable
                      as double,
            isPremium: null == isPremium
                ? _value.isPremium
                : isPremium // ignore: cast_nullable_to_non_nullable
                      as bool,
            premiumSince: freezed == premiumSince
                ? _value.premiumSince
                : premiumSince // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            birthdayNotificationsEnabled: null == birthdayNotificationsEnabled
                ? _value.birthdayNotificationsEnabled
                : birthdayNotificationsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            availableSeats: freezed == availableSeats
                ? _value.availableSeats
                : availableSeats // ignore: cast_nullable_to_non_nullable
                      as int?,
            seatsUpdatedAt: freezed == seatsUpdatedAt
                ? _value.seatsUpdatedAt
                : seatsUpdatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            waitlistEnabled: null == waitlistEnabled
                ? _value.waitlistEnabled
                : waitlistEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
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
    String? reviewNote,
    String? reviewedBy,
    @NullableTimestampConverter() DateTime? reviewedAt,
    String? paymentId,
    @NullableTimestampConverter() DateTime? subscriptionRenewsAt,
    bool isFoundingVenue,
    int freeOffersUsed,
    @NullableTimestampConverter() DateTime? freeOfferWindowEnd,
    bool firstPaymentAnnouncementPending,
    @NullableTimestampConverter() DateTime? revisionDeadline,
    bool verified,
    int likeCount,
    double rating,
    @TimestampConverter() DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
    @VenueSocialLinksConverter() VenueSocialLinks? socialLinks,
    String audienceRadiusMode,
    double audienceRadiusKm,
    bool isPremium,
    @NullableTimestampConverter() DateTime? premiumSince,
    bool birthdayNotificationsEnabled,
    int? availableSeats,
    @NullableTimestampConverter() DateTime? seatsUpdatedAt,
    bool waitlistEnabled,
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
    Object? reviewNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewedAt = freezed,
    Object? paymentId = freezed,
    Object? subscriptionRenewsAt = freezed,
    Object? isFoundingVenue = null,
    Object? freeOffersUsed = null,
    Object? freeOfferWindowEnd = freezed,
    Object? firstPaymentAnnouncementPending = null,
    Object? revisionDeadline = freezed,
    Object? verified = null,
    Object? likeCount = null,
    Object? rating = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? socialLinks = freezed,
    Object? audienceRadiusMode = null,
    Object? audienceRadiusKm = null,
    Object? isPremium = null,
    Object? premiumSince = freezed,
    Object? birthdayNotificationsEnabled = null,
    Object? availableSeats = freezed,
    Object? seatsUpdatedAt = freezed,
    Object? waitlistEnabled = null,
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
        paymentId: freezed == paymentId
            ? _value.paymentId
            : paymentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        subscriptionRenewsAt: freezed == subscriptionRenewsAt
            ? _value.subscriptionRenewsAt
            : subscriptionRenewsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isFoundingVenue: null == isFoundingVenue
            ? _value.isFoundingVenue
            : isFoundingVenue // ignore: cast_nullable_to_non_nullable
                  as bool,
        freeOffersUsed: null == freeOffersUsed
            ? _value.freeOffersUsed
            : freeOffersUsed // ignore: cast_nullable_to_non_nullable
                  as int,
        freeOfferWindowEnd: freezed == freeOfferWindowEnd
            ? _value.freeOfferWindowEnd
            : freeOfferWindowEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        firstPaymentAnnouncementPending: null == firstPaymentAnnouncementPending
            ? _value.firstPaymentAnnouncementPending
            : firstPaymentAnnouncementPending // ignore: cast_nullable_to_non_nullable
                  as bool,
        revisionDeadline: freezed == revisionDeadline
            ? _value.revisionDeadline
            : revisionDeadline // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        verified: null == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool,
        likeCount: null == likeCount
            ? _value.likeCount
            : likeCount // ignore: cast_nullable_to_non_nullable
                  as int,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        socialLinks: freezed == socialLinks
            ? _value.socialLinks
            : socialLinks // ignore: cast_nullable_to_non_nullable
                  as VenueSocialLinks?,
        audienceRadiusMode: null == audienceRadiusMode
            ? _value.audienceRadiusMode
            : audienceRadiusMode // ignore: cast_nullable_to_non_nullable
                  as String,
        audienceRadiusKm: null == audienceRadiusKm
            ? _value.audienceRadiusKm
            : audienceRadiusKm // ignore: cast_nullable_to_non_nullable
                  as double,
        isPremium: null == isPremium
            ? _value.isPremium
            : isPremium // ignore: cast_nullable_to_non_nullable
                  as bool,
        premiumSince: freezed == premiumSince
            ? _value.premiumSince
            : premiumSince // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        birthdayNotificationsEnabled: null == birthdayNotificationsEnabled
            ? _value.birthdayNotificationsEnabled
            : birthdayNotificationsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        availableSeats: freezed == availableSeats
            ? _value.availableSeats
            : availableSeats // ignore: cast_nullable_to_non_nullable
                  as int?,
        seatsUpdatedAt: freezed == seatsUpdatedAt
            ? _value.seatsUpdatedAt
            : seatsUpdatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        waitlistEnabled: null == waitlistEnabled
            ? _value.waitlistEnabled
            : waitlistEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
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
    this.status = 'pending',
    this.reviewNote,
    this.reviewedBy,
    @NullableTimestampConverter() this.reviewedAt,
    this.paymentId,
    @NullableTimestampConverter() this.subscriptionRenewsAt,
    this.isFoundingVenue = false,
    this.freeOffersUsed = 0,
    @NullableTimestampConverter() this.freeOfferWindowEnd,
    this.firstPaymentAnnouncementPending = false,
    @NullableTimestampConverter() this.revisionDeadline,
    this.verified = false,
    this.likeCount = 0,
    this.rating = 3.0,
    @TimestampConverter() required this.createdAt,
    @NullableTimestampConverter() this.updatedAt,
    @VenueSocialLinksConverter() this.socialLinks,
    this.audienceRadiusMode = 'distance',
    this.audienceRadiusKm = 1.0,
    this.isPremium = false,
    @NullableTimestampConverter() this.premiumSince,
    this.birthdayNotificationsEnabled = false,
    this.availableSeats,
    @NullableTimestampConverter() this.seatsUpdatedAt,
    this.waitlistEnabled = false,
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

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected'. New
  /// venues start 'pending' and stay invisible to discovery until an
  /// admin/moderator approves them — see firestore.rules, which
  /// blocks the owner from writing this field directly; only the
  /// admin panel's Server Actions (Admin SDK) may change it.
  @override
  @JsonKey()
  final String status;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected' — shown to the owner as the
  /// reason. Null otherwise.
  @override
  final String? reviewNote;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  @override
  final String? reviewedBy;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @override
  @NullableTimestampConverter()
  final DateTime? reviewedAt;

  /// The `payments/{paymentId}` doc backing this venue's most recent
  /// subscription charge — see `PaymentRecord`/`functions/src/
  /// index.ts`'s payment-refund state machine. Null on venues created
  /// before this field existed.
  @override
  final String? paymentId;

  /// When the category-based listing fee (see `_venueListingFeeFor`)
  /// next renews — set at creation to `createdAt + 30 days`, then
  /// pushed forward another 30 days each cycle by
  /// `renewVenueSubscriptions` (scheduled Cloud Function,
  /// functions/src/index.ts), which also writes the corresponding
  /// `payments/{id}` doc (`type: 'venue_subscription'`) for that
  /// cycle. Grant-of-trust like [paymentId] — only that Cloud
  /// Function may move it forward, never the owner's own client write
  /// (see firestore.rules). Null on venues created before this field
  /// existed — `renewVenueSubscriptions` treats a null the same as an
  /// overdue date so those venues enter the cycle on its next run.
  @override
  @NullableTimestampConverter()
  final DateTime? subscriptionRenewsAt;

  /// True for one of the first 1000 venues ever approved — see
  /// `assignFoundingVenueIfEligible` (Cloud Function, functions/src/
  /// index.ts), which sets this (with [freeOffersUsed]/
  /// [freeOfferWindowEnd]) the moment [status] first reaches
  /// 'approved', never at raw signup. Grant-of-trust — the owner can't
  /// self-grant this (see firestore.rules). Drives the "Bu təklif
  /// pulsuzdur" free-quota check in `submitOffer`/the offer create
  /// form; `false` (the default) for every venue outside the first
  /// 1000 and for any venue created before this field existed.
  @override
  @JsonKey()
  final bool isFoundingVenue;

  /// How many of [isFoundingVenue]'s 5 free offer placements this
  /// venue has used — incremented atomically inside `submitOffer`'s
  /// own transaction each time a free placement is granted, never by
  /// a direct client write (see firestore.rules). Meaningless when
  /// [isFoundingVenue] is false.
  @override
  @JsonKey()
  final int freeOffersUsed;

  /// The 1-month window [isFoundingVenue]'s free quota is valid
  /// within — set once, alongside [isFoundingVenue], to
  /// "first approval + 30 days". Null for a non-founding venue.
  @override
  @NullableTimestampConverter()
  final DateTime? freeOfferWindowEnd;

  /// True from the moment this venue's FIRST subscription payment
  /// clears (`applyPaymentOutcome`, functions/src/index.ts) until the
  /// owner dismisses the resulting confirmation card on
  /// `MyVenuesScreen` (`dismissFirstPaymentAnnouncement`). Read
  /// alongside [isFoundingVenue]/[subscriptionRenewsAt] at render
  /// time, not a frozen snapshot — see this field's own producer
  /// comment for why.
  @override
  @JsonKey()
  final bool firstPaymentAnnouncementPending;

  /// Only set while [status] is 'needs_revision' — the owner has this
  /// long to resubmit before `expireVenueRevisionDeadlines` (scheduled
  /// Cloud Function) auto-rejects the venue and refunds the payment.
  /// Cleared back to null by `resubmitVenue` on resubmission, and by
  /// the admin panel whenever [status] moves away from
  /// 'needs_revision'. Grant-of-trust like [status] itself — the owner
  /// can't extend their own deadline (see firestore.rules).
  @override
  @NullableTimestampConverter()
  final DateTime? revisionDeadline;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  @override
  @JsonKey()
  final bool verified;

  /// Denormalized count of `venues/{id}/likes` docs — written ONLY by
  /// the `onVenueLikeCreated`/`onVenueLikeDeleted` Cloud Function
  /// triggers (see functions/src/index.ts), never directly by the
  /// client (firestore.rules blocks that) so it can't be gamed by a
  /// raw Firestore write.
  @override
  @JsonKey()
  final int likeCount;

  /// 0-5, one decimal — derived purely from [likeCount] by the same
  /// triggers that maintain it (base 3.0 + 0.1 per 5 likes, capped at
  /// 5.0). Never set directly by the client.
  @override
  @JsonKey()
  final double rating;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @NullableTimestampConverter()
  final DateTime? updatedAt;

  /// Owner-provided WhatsApp/Instagram/TikTok — null (not an empty
  /// object) when the owner filled in none of the three, so
  /// `VenueProfileScreen` can tell "no social links at all" apart
  /// from "links exist but this specific one is unset" with one check.
  @override
  @VenueSocialLinksConverter()
  final VenueSocialLinks? socialLinks;

  /// 'distance' | 'country' | 'world' — same 3 modes as Discover's own
  /// `DiscoverRadiusSelection`, just persisted here since the owner
  /// picks one and it stays fixed, where Discover's version is
  /// transient per-viewer session state, never saved.
  @override
  @JsonKey()
  final String audienceRadiusMode;

  /// Only meaningful when [audienceRadiusMode] is 'distance' — radius
  /// (km) the owner-only "live audience" counter on
  /// [VenueProfileScreen] scans around [lat]/[lng] for recently-active
  /// `users` docs — see `location_providers.dart`'s
  /// `venueAudienceCountProvider`. Owner-editable from the create/edit
  /// form (same option set as Discover's own radius picker); defaults
  /// to 1km since venues have no other stored radius to default from.
  @override
  @JsonKey()
  final double audienceRadiusKm;

  /// Set only by a future paid-upgrade flow (never by the owner's own
  /// create/edit form — no client write path exists for this yet).
  /// Premium venues sort first within their radius in
  /// [nearbyVenuesProvider] and get a crown badge next to their name.
  @override
  @JsonKey()
  final bool isPremium;

  /// When [isPremium] most recently turned on, from the admin
  /// panel's toggle (`admin-panel/src/lib/actions/venues.ts`) — the
  /// only write path for this field. Re-toggling premium on again
  /// after turning it off resets this to the new grant time, since
  /// nothing tracks premium history beyond "currently on since X".
  /// Shown on `VenuePremiumInfoScreen`; `null` on venues predating
  /// this field.
  @override
  @NullableTimestampConverter()
  final DateTime? premiumSince;

  /// Whether `computeBirthdayMatches` (the daily birthday-offer
  /// matching Cloud Function) considers this venue at all — defaults
  /// to `category`'s membership in [kBirthdayEligibleVenueCategories]
  /// at creation time, owner-editable afterward from the create/edit
  /// form ONLY for categories in that set (every other category
  /// never shows the toggle, so this just stays `false` for them).
  @override
  @JsonKey()
  final bool birthdayNotificationsEnabled;

  /// Owner-set "current free seats" count (0-50), edited from the
  /// standalone seat-count sheet on `MyVenuesScreen` (NOT the
  /// create/edit form — this is meant for frequent, lightweight
  /// updates, not a full re-submit). Null means the owner has never
  /// turned this feature on — [SeatAvailabilityCard] on
  /// `VenueProfileScreen` renders nothing at all in that case, rather
  /// than showing a misleading "0 seats".
  @override
  final int? availableSeats;

  /// When [availableSeats] was last written — always set together
  /// with it (`FieldValue.serverTimestamp()`), null exactly when
  /// [availableSeats] is null. Powers the "X dəq əvvəl yeniləndi"
  /// caption under the card.
  @override
  @NullableTimestampConverter()
  final DateTime? seatsUpdatedAt;

  /// Owner's "Növbəni aktivləşdir/söndür" toggle for the walk-in
  /// waitlist feature (`venues/{id}/waitlist`) — false hides the
  /// "Sıraya yaz" button on `VenueProfileScreen`, but never affects
  /// entries already in the queue (they still see their own status
  /// and can still be called/seated normally).
  @override
  @JsonKey()
  final bool waitlistEnabled;

  @override
  String toString() {
    return 'Venue(id: $id, ownerId: $ownerId, name: $name, category: $category, photoUrl: $photoUrl, gallery: $gallery, lat: $lat, lng: $lng, address: $address, country: $country, openingHours: $openingHours, status: $status, reviewNote: $reviewNote, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, paymentId: $paymentId, subscriptionRenewsAt: $subscriptionRenewsAt, isFoundingVenue: $isFoundingVenue, freeOffersUsed: $freeOffersUsed, freeOfferWindowEnd: $freeOfferWindowEnd, firstPaymentAnnouncementPending: $firstPaymentAnnouncementPending, revisionDeadline: $revisionDeadline, verified: $verified, likeCount: $likeCount, rating: $rating, createdAt: $createdAt, updatedAt: $updatedAt, socialLinks: $socialLinks, audienceRadiusMode: $audienceRadiusMode, audienceRadiusKm: $audienceRadiusKm, isPremium: $isPremium, premiumSince: $premiumSince, birthdayNotificationsEnabled: $birthdayNotificationsEnabled, availableSeats: $availableSeats, seatsUpdatedAt: $seatsUpdatedAt, waitlistEnabled: $waitlistEnabled)';
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
            (identical(other.reviewNote, reviewNote) ||
                other.reviewNote == reviewNote) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.paymentId, paymentId) ||
                other.paymentId == paymentId) &&
            (identical(other.subscriptionRenewsAt, subscriptionRenewsAt) ||
                other.subscriptionRenewsAt == subscriptionRenewsAt) &&
            (identical(other.isFoundingVenue, isFoundingVenue) ||
                other.isFoundingVenue == isFoundingVenue) &&
            (identical(other.freeOffersUsed, freeOffersUsed) ||
                other.freeOffersUsed == freeOffersUsed) &&
            (identical(other.freeOfferWindowEnd, freeOfferWindowEnd) ||
                other.freeOfferWindowEnd == freeOfferWindowEnd) &&
            (identical(
                  other.firstPaymentAnnouncementPending,
                  firstPaymentAnnouncementPending,
                ) ||
                other.firstPaymentAnnouncementPending ==
                    firstPaymentAnnouncementPending) &&
            (identical(other.revisionDeadline, revisionDeadline) ||
                other.revisionDeadline == revisionDeadline) &&
            (identical(other.verified, verified) ||
                other.verified == verified) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.socialLinks, socialLinks) ||
                other.socialLinks == socialLinks) &&
            (identical(other.audienceRadiusMode, audienceRadiusMode) ||
                other.audienceRadiusMode == audienceRadiusMode) &&
            (identical(other.audienceRadiusKm, audienceRadiusKm) ||
                other.audienceRadiusKm == audienceRadiusKm) &&
            (identical(other.isPremium, isPremium) ||
                other.isPremium == isPremium) &&
            (identical(other.premiumSince, premiumSince) ||
                other.premiumSince == premiumSince) &&
            (identical(
                  other.birthdayNotificationsEnabled,
                  birthdayNotificationsEnabled,
                ) ||
                other.birthdayNotificationsEnabled ==
                    birthdayNotificationsEnabled) &&
            (identical(other.availableSeats, availableSeats) ||
                other.availableSeats == availableSeats) &&
            (identical(other.seatsUpdatedAt, seatsUpdatedAt) ||
                other.seatsUpdatedAt == seatsUpdatedAt) &&
            (identical(other.waitlistEnabled, waitlistEnabled) ||
                other.waitlistEnabled == waitlistEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
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
    reviewNote,
    reviewedBy,
    reviewedAt,
    paymentId,
    subscriptionRenewsAt,
    isFoundingVenue,
    freeOffersUsed,
    freeOfferWindowEnd,
    firstPaymentAnnouncementPending,
    revisionDeadline,
    verified,
    likeCount,
    rating,
    createdAt,
    updatedAt,
    socialLinks,
    audienceRadiusMode,
    audienceRadiusKm,
    isPremium,
    premiumSince,
    birthdayNotificationsEnabled,
    availableSeats,
    seatsUpdatedAt,
    waitlistEnabled,
  ]);

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
    final String? reviewNote,
    final String? reviewedBy,
    @NullableTimestampConverter() final DateTime? reviewedAt,
    final String? paymentId,
    @NullableTimestampConverter() final DateTime? subscriptionRenewsAt,
    final bool isFoundingVenue,
    final int freeOffersUsed,
    @NullableTimestampConverter() final DateTime? freeOfferWindowEnd,
    final bool firstPaymentAnnouncementPending,
    @NullableTimestampConverter() final DateTime? revisionDeadline,
    final bool verified,
    final int likeCount,
    final double rating,
    @TimestampConverter() required final DateTime createdAt,
    @NullableTimestampConverter() final DateTime? updatedAt,
    @VenueSocialLinksConverter() final VenueSocialLinks? socialLinks,
    final String audienceRadiusMode,
    final double audienceRadiusKm,
    final bool isPremium,
    @NullableTimestampConverter() final DateTime? premiumSince,
    final bool birthdayNotificationsEnabled,
    final int? availableSeats,
    @NullableTimestampConverter() final DateTime? seatsUpdatedAt,
    final bool waitlistEnabled,
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

  /// 'pending' | 'approved' | 'needs_revision' | 'rejected'. New
  /// venues start 'pending' and stay invisible to discovery until an
  /// admin/moderator approves them — see firestore.rules, which
  /// blocks the owner from writing this field directly; only the
  /// admin panel's Server Actions (Admin SDK) may change it.
  @override
  String get status;

  /// Set by the reviewing admin/moderator when [status] is
  /// 'needs_revision' or 'rejected' — shown to the owner as the
  /// reason. Null otherwise.
  @override
  String? get reviewNote;

  /// Admin/moderator uid who last set [status]. Null until reviewed.
  @override
  String? get reviewedBy;

  /// When [reviewedBy] last set [status]. Null until reviewed.
  @override
  @NullableTimestampConverter()
  DateTime? get reviewedAt;

  /// The `payments/{paymentId}` doc backing this venue's most recent
  /// subscription charge — see `PaymentRecord`/`functions/src/
  /// index.ts`'s payment-refund state machine. Null on venues created
  /// before this field existed.
  @override
  String? get paymentId;

  /// When the category-based listing fee (see `_venueListingFeeFor`)
  /// next renews — set at creation to `createdAt + 30 days`, then
  /// pushed forward another 30 days each cycle by
  /// `renewVenueSubscriptions` (scheduled Cloud Function,
  /// functions/src/index.ts), which also writes the corresponding
  /// `payments/{id}` doc (`type: 'venue_subscription'`) for that
  /// cycle. Grant-of-trust like [paymentId] — only that Cloud
  /// Function may move it forward, never the owner's own client write
  /// (see firestore.rules). Null on venues created before this field
  /// existed — `renewVenueSubscriptions` treats a null the same as an
  /// overdue date so those venues enter the cycle on its next run.
  @override
  @NullableTimestampConverter()
  DateTime? get subscriptionRenewsAt;

  /// True for one of the first 1000 venues ever approved — see
  /// `assignFoundingVenueIfEligible` (Cloud Function, functions/src/
  /// index.ts), which sets this (with [freeOffersUsed]/
  /// [freeOfferWindowEnd]) the moment [status] first reaches
  /// 'approved', never at raw signup. Grant-of-trust — the owner can't
  /// self-grant this (see firestore.rules). Drives the "Bu təklif
  /// pulsuzdur" free-quota check in `submitOffer`/the offer create
  /// form; `false` (the default) for every venue outside the first
  /// 1000 and for any venue created before this field existed.
  @override
  bool get isFoundingVenue;

  /// How many of [isFoundingVenue]'s 5 free offer placements this
  /// venue has used — incremented atomically inside `submitOffer`'s
  /// own transaction each time a free placement is granted, never by
  /// a direct client write (see firestore.rules). Meaningless when
  /// [isFoundingVenue] is false.
  @override
  int get freeOffersUsed;

  /// The 1-month window [isFoundingVenue]'s free quota is valid
  /// within — set once, alongside [isFoundingVenue], to
  /// "first approval + 30 days". Null for a non-founding venue.
  @override
  @NullableTimestampConverter()
  DateTime? get freeOfferWindowEnd;

  /// True from the moment this venue's FIRST subscription payment
  /// clears (`applyPaymentOutcome`, functions/src/index.ts) until the
  /// owner dismisses the resulting confirmation card on
  /// `MyVenuesScreen` (`dismissFirstPaymentAnnouncement`). Read
  /// alongside [isFoundingVenue]/[subscriptionRenewsAt] at render
  /// time, not a frozen snapshot — see this field's own producer
  /// comment for why.
  @override
  bool get firstPaymentAnnouncementPending;

  /// Only set while [status] is 'needs_revision' — the owner has this
  /// long to resubmit before `expireVenueRevisionDeadlines` (scheduled
  /// Cloud Function) auto-rejects the venue and refunds the payment.
  /// Cleared back to null by `resubmitVenue` on resubmission, and by
  /// the admin panel whenever [status] moves away from
  /// 'needs_revision'. Grant-of-trust like [status] itself — the owner
  /// can't extend their own deadline (see firestore.rules).
  @override
  @NullableTimestampConverter()
  DateTime? get revisionDeadline;

  /// Reserved for a future admin-verification badge — nothing sets
  /// this true yet, so it never renders today.
  @override
  bool get verified;

  /// Denormalized count of `venues/{id}/likes` docs — written ONLY by
  /// the `onVenueLikeCreated`/`onVenueLikeDeleted` Cloud Function
  /// triggers (see functions/src/index.ts), never directly by the
  /// client (firestore.rules blocks that) so it can't be gamed by a
  /// raw Firestore write.
  @override
  int get likeCount;

  /// 0-5, one decimal — derived purely from [likeCount] by the same
  /// triggers that maintain it (base 3.0 + 0.1 per 5 likes, capped at
  /// 5.0). Never set directly by the client.
  @override
  double get rating;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @NullableTimestampConverter()
  DateTime? get updatedAt;

  /// Owner-provided WhatsApp/Instagram/TikTok — null (not an empty
  /// object) when the owner filled in none of the three, so
  /// `VenueProfileScreen` can tell "no social links at all" apart
  /// from "links exist but this specific one is unset" with one check.
  @override
  @VenueSocialLinksConverter()
  VenueSocialLinks? get socialLinks;

  /// 'distance' | 'country' | 'world' — same 3 modes as Discover's own
  /// `DiscoverRadiusSelection`, just persisted here since the owner
  /// picks one and it stays fixed, where Discover's version is
  /// transient per-viewer session state, never saved.
  @override
  String get audienceRadiusMode;

  /// Only meaningful when [audienceRadiusMode] is 'distance' — radius
  /// (km) the owner-only "live audience" counter on
  /// [VenueProfileScreen] scans around [lat]/[lng] for recently-active
  /// `users` docs — see `location_providers.dart`'s
  /// `venueAudienceCountProvider`. Owner-editable from the create/edit
  /// form (same option set as Discover's own radius picker); defaults
  /// to 1km since venues have no other stored radius to default from.
  @override
  double get audienceRadiusKm;

  /// Set only by a future paid-upgrade flow (never by the owner's own
  /// create/edit form — no client write path exists for this yet).
  /// Premium venues sort first within their radius in
  /// [nearbyVenuesProvider] and get a crown badge next to their name.
  @override
  bool get isPremium;

  /// When [isPremium] most recently turned on, from the admin
  /// panel's toggle (`admin-panel/src/lib/actions/venues.ts`) — the
  /// only write path for this field. Re-toggling premium on again
  /// after turning it off resets this to the new grant time, since
  /// nothing tracks premium history beyond "currently on since X".
  /// Shown on `VenuePremiumInfoScreen`; `null` on venues predating
  /// this field.
  @override
  @NullableTimestampConverter()
  DateTime? get premiumSince;

  /// Whether `computeBirthdayMatches` (the daily birthday-offer
  /// matching Cloud Function) considers this venue at all — defaults
  /// to `category`'s membership in [kBirthdayEligibleVenueCategories]
  /// at creation time, owner-editable afterward from the create/edit
  /// form ONLY for categories in that set (every other category
  /// never shows the toggle, so this just stays `false` for them).
  @override
  bool get birthdayNotificationsEnabled;

  /// Owner-set "current free seats" count (0-50), edited from the
  /// standalone seat-count sheet on `MyVenuesScreen` (NOT the
  /// create/edit form — this is meant for frequent, lightweight
  /// updates, not a full re-submit). Null means the owner has never
  /// turned this feature on — [SeatAvailabilityCard] on
  /// `VenueProfileScreen` renders nothing at all in that case, rather
  /// than showing a misleading "0 seats".
  @override
  int? get availableSeats;

  /// When [availableSeats] was last written — always set together
  /// with it (`FieldValue.serverTimestamp()`), null exactly when
  /// [availableSeats] is null. Powers the "X dəq əvvəl yeniləndi"
  /// caption under the card.
  @override
  @NullableTimestampConverter()
  DateTime? get seatsUpdatedAt;

  /// Owner's "Növbəni aktivləşdir/söndür" toggle for the walk-in
  /// waitlist feature (`venues/{id}/waitlist`) — false hides the
  /// "Sıraya yaz" button on `VenueProfileScreen`, but never affects
  /// entries already in the queue (they still see their own status
  /// and can still be called/seated normally).
  @override
  bool get waitlistEnabled;

  /// Create a copy of Venue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueImplCopyWith<_$VenueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
