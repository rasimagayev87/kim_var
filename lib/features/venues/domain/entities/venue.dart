import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue.freezed.dart';
part 'venue.g.dart';

/// Self-service-submitted local businesses (Kəşf et → Məkanlar).
/// [likeCount]/[rating] (below) are the pre-existing like-based score;
/// [ratingAverage]/[ratingCount] are the separate, review-based one
/// (Faza 1: waitlist-`seated`-verified visits only — see
/// `VenueReviewsSection`/`firestore.rules`' `reviews` collection). The
/// two coexist deliberately rather than merging, since one is "how
/// many people liked this venue" and the other is an actual star
/// rating from confirmed guests.
///
/// This exact ordering is the client-specified list and drives the
/// category picker's default (pre-search) order. [other] is not part
/// of that list — it's kept as a required fallback target for
/// [VenueCategoryConverter]'s `orElse`, so a venue whose stored
/// category no longer matches anything (e.g. one created before this
/// list replaced the previous one) still parses instead of throwing.
enum VenueCategory {
  restaurant,
  pub,
  coffeeShop,
  fastFood,
  teaHouse,
  sweetsShop,
  hotel,
  motel,
  cinema,
  karaoke,
  gameHall,
  nightClub,
  fitness,
  gym,
  spa,
  footballField,
  clinic,
  beautySalon,
  barbershop,
  cosmetology,
  tattoo,
  photoStudio,
  kidsEntertainment,
  // Added later than the original 24 above — appended as their own
  // loosely-grouped block rather than interleaved, per explicit
  // product direction that ordering among the new ones only needed to
  // be "sensible", not alphabetical or woven into the original list.
  pharmacyOptics,
  dentalClinic,
  perfumeryCosmetics,
  carWash,
  carRepair,
  supermarket,
  bookstoreStationery,
  petStore,
  tailor,
  dryCleaning,
  applianceRepair,
  tutoringCenter,
  // Offer-only categories — see `lib/core/constants/category_capabilities.dart`.
  // These three can never create Events/PinBox/Waitlist entries,
  // enforced both client-side (capability model) and server-side
  // (firestore.rules' `isOfferOnlyCategory`, `joinWaitlist`'s
  // `OFFER_ONLY_VENUE_CATEGORIES` in functions/src/index.ts).
  wineHouse,
  homeServices,
  realEstate,
  // [independentArtist] is the odd one out — the one category with its
  // own venue-level "İzlə" (follow) feature, see `_VenueFollowButton`
  // in venue_profile_screen.dart. `wineBar`/`cleaningServices` were
  // removed from the product entirely (no venue ever used either —
  // confirmed via a Firestore query before deletion) rather than kept
  // as unused enum members.
  independentArtist,
  other,
}

/// Categories the birthday-offer matching Cloud Function
/// (`computeBirthdayMatches` in `functions/src/index.ts`) considers by
/// default — every other category defaults to opted out AND doesn't
/// show the toggle in `CreateVenueScreen` at all, per product decision
/// to keep this simple until an "opt-in other categories" list exists.
/// A venue in one of these categories still starts out
/// [Venue.birthdayNotificationsEnabled] `true` only as a DEFAULT — the
/// owner can turn it back off from the create/edit form.
/// `hotel` and `kidsEntertainment` were removed on 2026-08-31 (15 → 13)
/// on product direction. Mirrored server-side in
/// `functions/src/venue-categories.ts`; the parity test
/// `tests/rules/venue-categories.test.ts` fails if the two drift.
const kBirthdayEligibleVenueCategories = <VenueCategory>{
  VenueCategory.restaurant,
  VenueCategory.pub,
  VenueCategory.coffeeShop,
  VenueCategory.sweetsShop,
  VenueCategory.fastFood,
  VenueCategory.cinema,
  VenueCategory.karaoke,
  VenueCategory.nightClub,
  VenueCategory.spa,
  VenueCategory.cosmetology,
  VenueCategory.photoStudio,
  VenueCategory.beautySalon,
  VenueCategory.perfumeryCosmetics,
};

/// Venues that may create Events.
///
/// Previously read from `config/eventCategories` in Firestore — a list
/// no server code ever consulted, so it decorated the UI while
/// `firestore.rules` allowed any non-offer-only category to create an
/// event. Now a code constant on both sides; see
/// `functions/src/venue-categories.ts` for why the config documents
/// were retired rather than kept as a second source of truth.
const kEventEligibleVenueCategories = <VenueCategory>{
  VenueCategory.restaurant,
  VenueCategory.pub,
  VenueCategory.fastFood,
  VenueCategory.cinema,
  VenueCategory.nightClub,
  VenueCategory.kidsEntertainment,
  VenueCategory.independentArtist,
};

/// Venues that may run a walk-in queue ("Növbə"). Same reasoning as
/// [kEventEligibleVenueCategories]; replaces `config/waitlistCategories`.
const kWaitlistEligibleVenueCategories = <VenueCategory>{
  VenueCategory.restaurant,
  VenueCategory.pub,
  VenueCategory.fastFood,
  VenueCategory.coffeeShop,
  VenueCategory.teaHouse,
  VenueCategory.karaoke,
  VenueCategory.sweetsShop,
  VenueCategory.gameHall,
  VenueCategory.spa,
  VenueCategory.carWash,
};

/// Categories PinBox (surprise-box discount sales) can be created for —
/// a fixed product decision, unlike Tədbir/Növbə's category allowlists
/// which live in Firestore (`config/eventCategories`/`waitlistCategories`)
/// and are admin-editable without a release. This one is hardcoded on
/// purpose: the product owner explicitly locked these 6 categories in
/// during PinBox's spec (perishable/quick-turnover goods only), with no
/// stated intent to make it configurable.
const kPinboxEligibleVenueCategories = <VenueCategory>{
  VenueCategory.restaurant,
  VenueCategory.coffeeShop,
  VenueCategory.fastFood,
  VenueCategory.sweetsShop,
  VenueCategory.perfumeryCosmetics,
  VenueCategory.supermarket,
};

const _venueCategoryIcons = <VenueCategory, IconData>{
  VenueCategory.restaurant: Icons.restaurant_outlined,
  VenueCategory.pub: Icons.local_bar_outlined,
  VenueCategory.coffeeShop: Icons.coffee_outlined,
  VenueCategory.fastFood: Icons.lunch_dining_outlined,
  VenueCategory.teaHouse: Icons.emoji_food_beverage_outlined,
  VenueCategory.sweetsShop: Icons.cake_outlined,
  VenueCategory.hotel: Icons.hotel_outlined,
  VenueCategory.motel: Icons.cottage_outlined,
  VenueCategory.cinema: Icons.theaters_outlined,
  VenueCategory.karaoke: Icons.mic_outlined,
  VenueCategory.gameHall: Icons.sports_esports_outlined,
  VenueCategory.nightClub: Icons.nightlife_outlined,
  VenueCategory.fitness: Icons.fitness_center_outlined,
  VenueCategory.gym: Icons.sports_outlined,
  VenueCategory.spa: Icons.spa_outlined,
  VenueCategory.footballField: Icons.sports_soccer_outlined,
  VenueCategory.clinic: Icons.medical_services_outlined,
  VenueCategory.beautySalon: Icons.content_cut_outlined,
  VenueCategory.barbershop: Icons.face_outlined,
  VenueCategory.cosmetology: Icons.auto_fix_high_outlined,
  VenueCategory.tattoo: Icons.brush_outlined,
  VenueCategory.photoStudio: Icons.photo_camera_outlined,
  VenueCategory.kidsEntertainment: Icons.child_care_outlined,
  VenueCategory.pharmacyOptics: Icons.local_pharmacy_outlined,
  VenueCategory.dentalClinic: Icons.medication_outlined,
  VenueCategory.perfumeryCosmetics: Icons.soap_outlined,
  VenueCategory.carWash: Icons.local_car_wash_outlined,
  VenueCategory.carRepair: Icons.car_repair_outlined,
  VenueCategory.supermarket: Icons.local_grocery_store_outlined,
  VenueCategory.bookstoreStationery: Icons.menu_book_outlined,
  VenueCategory.petStore: Icons.pets_outlined,
  VenueCategory.tailor: Icons.checkroom_outlined,
  VenueCategory.dryCleaning: Icons.local_laundry_service_outlined,
  VenueCategory.applianceRepair: Icons.handyman_outlined,
  VenueCategory.tutoringCenter: Icons.school_outlined,
  VenueCategory.wineHouse: Icons.wine_bar_outlined,
  VenueCategory.homeServices: Icons.cleaning_services_outlined,
  VenueCategory.realEstate: Icons.house_outlined,
  VenueCategory.independentArtist: Icons.campaign_outlined,
  VenueCategory.other: Icons.category_outlined,
};

IconData venueCategoryIcon(VenueCategory category) =>
    _venueCategoryIcons[category]!;

/// One day's open/close pair, both "HH:mm". Absence of an entry for a
/// weekday in [OpeningHours.schedule] means closed that day. Kept as a
/// plain class (not Freezed) — its Firestore shape (int weekday keys,
/// nullable per-day entries) doesn't map cleanly onto standard JSON
/// codegen, and it was already a small, well-tested immutable value
/// type with no behavior worth regenerating.
class DayHours {
  final String open;
  final String close;

  const DayHours({required this.open, required this.close});

  Map<String, dynamic> toMap() => {'open': open, 'close': close};

  static DayHours? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final open = map['open'] as String?;
    final close = map['close'] as String?;
    if (open == null || close == null) return null;
    return DayHours(open: open, close: close);
  }
}

/// Weekday keys are ISO weekday numbers as strings ("1" = Monday ...
/// "7" = Sunday) — Firestore map keys must be strings, and this keeps
/// the raw document trivially inspectable. Always fully populated
/// (7 entries) by the form — a day with no [DayHours] entry there means
/// "closed that day", not "unknown".
class OpeningHours {
  final bool is24h;
  final Map<int, DayHours?> schedule;

  const OpeningHours({this.is24h = false, this.schedule = const {}});

  bool get hasAnyOpenDay => is24h || schedule.values.any((d) => d != null);

  Map<String, dynamic> toMap() {
    return {
      'is24h': is24h,
      'schedule': {
        for (final entry in schedule.entries)
          '${entry.key}': entry.value?.toMap(),
      },
    };
  }

  static OpeningHours fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OpeningHours();
    final rawSchedule = map['schedule'] as Map?;
    final schedule = <int, DayHours?>{
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: DayHours.fromMap(
          (rawSchedule?['$weekday'] as Map?)?.cast<String, dynamic>(),
        ),
    };
    return OpeningHours(
      is24h: map['is24h'] as bool? ?? false,
      schedule: schedule,
    );
  }
}

/// Optional owner-provided social profiles, shown as extra
/// contact/directions buttons on the venue profile screen — same
/// plain-class-with-toMap/fromMap shape as [DayHours]/[OpeningHours],
/// since it's a small immutable value type with no behavior worth a
/// Freezed nested class for. All three fields are raw, un-prefixed
/// values (a phone number, a username, a username) — the profile
/// screen is what turns each into a real `wa.me`/`instagram.com`/
/// `tiktok.com` URL, so this stays storage-shaped, not display-shaped.
class VenueSocialLinks {
  final String? whatsapp;
  final String? instagram;
  final String? tiktok;

  const VenueSocialLinks({this.whatsapp, this.instagram, this.tiktok});

  bool get isEmpty => whatsapp == null && instagram == null && tiktok == null;

  Map<String, dynamic> toMap() => {
    if (whatsapp != null) 'whatsapp': whatsapp,
    if (instagram != null) 'instagram': instagram,
    if (tiktok != null) 'tiktok': tiktok,
  };

  static VenueSocialLinks? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final whatsapp = map['whatsapp'] as String?;
    final instagram = map['instagram'] as String?;
    final tiktok = map['tiktok'] as String?;
    if (whatsapp == null && instagram == null && tiktok == null) return null;
    return VenueSocialLinks(
      whatsapp: whatsapp,
      instagram: instagram,
      tiktok: tiktok,
    );
  }
}

class VenueSocialLinksConverter
    implements JsonConverter<VenueSocialLinks?, Map<String, dynamic>?> {
  const VenueSocialLinksConverter();

  @override
  VenueSocialLinks? fromJson(Map<String, dynamic>? json) =>
      VenueSocialLinks.fromMap(json);

  @override
  Map<String, dynamic>? toJson(VenueSocialLinks? links) => links?.toMap();
}

class VenueCategoryConverter implements JsonConverter<VenueCategory, String?> {
  const VenueCategoryConverter();

  @override
  VenueCategory fromJson(String? json) => VenueCategory.values.firstWhere(
    (c) => c.name == json,
    orElse: () => VenueCategory.other,
  );

  @override
  String toJson(VenueCategory category) => category.name;
}

class OpeningHoursConverter
    implements JsonConverter<OpeningHours, Map<String, dynamic>?> {
  const OpeningHoursConverter();

  @override
  OpeningHours fromJson(Map<String, dynamic>? json) =>
      OpeningHours.fromMap(json);

  @override
  Map<String, dynamic> toJson(OpeningHours hours) => hours.toMap();
}

/// Accepts either a Firestore [Timestamp] (reading from a live
/// snapshot) or a [DateTime] (round-tripping an already-hydrated
/// model), since `Venue.fromJson` is also used to reconstruct a model
/// from `toJson()` output that never touched Firestore.
class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    return DateTime.now();
  }

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    return null;
  }

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}

@freezed
class Venue with _$Venue {
  const Venue._();

  const factory Venue({
    required String id,
    required String ownerId,
    required String name,
    @VenueCategoryConverter() required VenueCategory category,
    String? photoUrl,

    /// Additional photos beyond [photoUrl] — schema-ready for a future
    /// gallery/carousel on the venue profile screen. Empty until that
    /// upload flow exists; nothing writes to this yet.
    @Default(<String>[]) List<String> gallery,
    required double lat,
    required double lng,
    required String address,

    /// Reverse-geocoded alongside [address] at pick time — powers "Ölkə
    /// üzrə" discovery (same mechanism as a user's own profile country
    /// in `location_providers.dart`'s `_countryCandidatesProvider`).
    /// Null if geocoding couldn't resolve a country for the picked point.
    String? country,
    @OpeningHoursConverter() required OpeningHours openingHours,

    /// 'pending' | 'approved' | 'needs_revision' | 'rejected'. New
    /// venues start 'pending' and stay invisible to discovery until an
    /// admin/moderator approves them — see firestore.rules, which
    /// blocks the owner from writing this field directly; only the
    /// admin panel's Server Actions (Admin SDK) may change it.
    @Default('pending') String status,

    /// Set by the reviewing admin/moderator when [status] is
    /// 'needs_revision' or 'rejected' — shown to the owner as the
    /// reason. Null otherwise.
    String? reviewNote,

    /// Admin/moderator uid who last set [status]. Null until reviewed.
    String? reviewedBy,

    /// When [reviewedBy] last set [status]. Null until reviewed.
    @NullableTimestampConverter() DateTime? reviewedAt,

    /// The `payments/{paymentId}` doc backing this venue's most recent
    /// subscription charge — see `PaymentRecord`/`functions/src/
    /// index.ts`'s payment-refund state machine. Null on venues created
    /// before this field existed.
    String? paymentId,

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
    @NullableTimestampConverter() DateTime? subscriptionRenewsAt,

    /// The "PeakPin Biznes Xidmətlərinin Publik Ofertası" version this
    /// venue's owner most recently accepted — set only by
    /// `applyPaymentOutcome` (functions/src/index.ts) once a payment it
    /// was attached to actually succeeds, never by the client directly
    /// (see firestore.rules). Compared against
    /// `AppConfig.businessOfferVersion` to decide whether a fresh
    /// acceptance is required before the next subscription payment.
    /// Null on venues created before this feature existed.
    String? offerAcceptedVersion,

    /// Server time of the acceptance recorded in [offerAcceptedVersion].
    /// Grant-of-trust, same as [subscriptionRenewsAt].
    @NullableTimestampConverter() DateTime? offerAcceptedAt,

    /// `"<appVersion> / <platform>"` the acceptance was made from —
    /// audit trail only, same format as the version-telemetry fields on
    /// `users/{uid}` (`firebase_auth_repository._maybeWriteVersionTelemetry`).
    String? offerAcceptedFrom,

    /// The exact document URL shown to the owner at acceptance time —
    /// kept alongside [offerAcceptedVersion] since `AppConfig.urlBusinessOffer`
    /// can change independently of the version number.
    String? offerDocumentUrl,

    /// True for one of the first 1000 venues ever approved — see
    /// `assignFoundingVenueIfEligible` (Cloud Function, functions/src/
    /// index.ts), which sets this the moment [status] first reaches
    /// 'approved', never at raw signup. Grant-of-trust — the owner can't
    /// self-grant this (see firestore.rules).
    ///
    /// Its remaining perk is the "1 ay ödə, 1 ay hədiyyə al" extra
    /// billing cycle. The free-campaign half was replaced by
    /// [freeCampaignsUsed]'s subscription-tier allowance.
    @Default(false) bool isFoundingVenue,

    /// How many free campaigns this venue has used in the CURRENT
    /// subscription period — held inside `submitOffer`'s transaction
    /// when a campaign is created for free, given back if that campaign
    /// is rejected or deleted before it publishes, and reset to 0 by
    /// `applyPaymentOutcome` when a new period is paid for. Never
    /// written by a client (see firestore.rules' venue blocklist).
    ///
    /// The allowance itself comes from the venue's subscription tier —
    /// `FREE_CAMPAIGNS_BY_SUBSCRIPTION_TIER` in `venue-fees.ts`, mirrored
    /// as [freeCampaignQuotaFor] on the Dart side.
    @Default(0) int freeCampaignsUsed,

    /// The start of the period [freeCampaignsUsed] is counted within —
    /// one subscription cycle back from [subscriptionRenewsAt]. Drives
    /// the "quota renews on {date}" line in the UI. Null until the
    /// venue's first subscription payment clears.
    @NullableTimestampConverter() DateTime? freeCampaignPeriodStart,

    /// RETIRED — the founding venues' 5-free-placements-in-30-days
    /// perk, replaced by [freeCampaignsUsed]. No server code reads or
    /// writes these any more; they survive only on documents that
    /// already carried them, because deleting production data was not
    /// that change's business. Do not build on them.
    @Default(0) int freeOffersUsed,

    /// RETIRED — see [freeOffersUsed].
    @NullableTimestampConverter() DateTime? freeOfferWindowEnd,

    /// True from the moment this venue's FIRST subscription payment
    /// clears (`applyPaymentOutcome`, functions/src/index.ts) until the
    /// owner dismisses the resulting confirmation card on
    /// `MyVenuesScreen` (`dismissFirstPaymentAnnouncement`). Read
    /// alongside [isFoundingVenue]/[subscriptionRenewsAt] at render
    /// time, not a frozen snapshot — see this field's own producer
    /// comment for why.
    @Default(false) bool firstPaymentAnnouncementPending,

    /// Only set while [status] is 'needs_revision' — the owner has this
    /// long to resubmit before `expireVenueRevisionDeadlines` (scheduled
    /// Cloud Function) auto-rejects the venue and refunds the payment.
    /// Cleared back to null by `resubmitVenue` on resubmission, and by
    /// the admin panel whenever [status] moves away from
    /// 'needs_revision'. Grant-of-trust like [status] itself — the owner
    /// can't extend their own deadline (see firestore.rules).
    @NullableTimestampConverter() DateTime? revisionDeadline,

    /// Reserved for a future admin-verification badge — nothing sets
    /// this true yet, so it never renders today.
    @Default(false) bool verified,

    /// Denormalized count of `venues/{id}/likes` docs — written ONLY by
    /// the `onVenueLikeCreated`/`onVenueLikeDeleted` Cloud Function
    /// triggers (see functions/src/index.ts), never directly by the
    /// client (firestore.rules blocks that) so it can't be gamed by a
    /// raw Firestore write.
    @Default(0) int likeCount,

    /// 0-5, one decimal — derived purely from [likeCount] by the same
    /// triggers that maintain it (base 3.0 + 0.1 per 5 likes, capped at
    /// 5.0). Never set directly by the client.
    @Default(3.0) double rating,

    /// The review-based rating — plain average of every `reviews`
    /// doc's `rating` field for this venue, recomputed from scratch by
    /// `onReviewWritten` (functions/src/index.ts) on every review
    /// create/update/delete. 0 with [ratingCount] 0 means "no reviews
    /// yet", not "reviewed as zero stars" — `VenueReviewsSection`
    /// never renders this pair at all in that case.
    @Default(0.0) double ratingAverage,
    @Default(0) int ratingCount,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,

    /// Owner-provided WhatsApp/Instagram/TikTok — null (not an empty
    /// object) when the owner filled in none of the three, so
    /// `VenueProfileScreen` can tell "no social links at all" apart
    /// from "links exist but this specific one is unset" with one check.
    @VenueSocialLinksConverter() VenueSocialLinks? socialLinks,

    /// Distance-only going forward — the create/edit form's picker only
    /// ever writes 'distance' now (a whole-country/worldwide live
    /// audience count isn't a meaningful number the way nearby foot
    /// traffic is). 'country'/'world' remain valid, READ-only values on
    /// venues that already had them before this change — not force
    /// -migrated, `venueAudienceCountProvider` still has working
    /// branches for both. Reused from Discover's own
    /// `DiscoverRadiusSelection` type purely for the 3-value string
    /// shape, not because all 3 stay pickable here.
    @Default('distance') String audienceRadiusMode,

    /// Only meaningful when [audienceRadiusMode] is 'distance' — radius
    /// (km) the owner-only "live audience" counter on
    /// [VenueProfileScreen] scans around [lat]/[lng] for recently-active
    /// `users` docs — see `location_providers.dart`'s
    /// `venueAudienceCountProvider`. Owner-editable from the create/edit
    /// form's 6 fixed distance options (100m/500m/1/5/10/30km) — the
    /// ONE field edit exempt from re-triggering moderation review, see
    /// the `updateVenue` Cloud Function's own doc comment
    /// (functions/src/index.ts); defaults to 1km since venues have no
    /// other stored radius to default from.
    @Default(1.0) double audienceRadiusKm,

    /// Set either by a real Epoint payment (`applyPaymentOutcome`'s
    /// `venue_premium` branch, functions/src/index.ts, via the owner's
    /// own "Məkanı premium et" checkout) or by the admin panel's
    /// manual toggle (`admin-panel/src/lib/actions/venues.ts`) — never
    /// directly by the client (blocked in firestore.rules). Premium
    /// venues sort first within their radius in [nearbyVenuesProvider]
    /// (rotating among themselves every 5 minutes if more than one)
    /// and get a crown badge next to their name.
    @Default(false) bool isPremium,

    /// When [isPremium] most recently turned on — either a real
    /// payment's first activation or the admin panel's toggle. Only
    /// resets on a not-premium → premium transition; a renewal
    /// purchased while already premium (see [premiumExpiresAt]) does
    /// NOT touch this, since nothing tracks premium history beyond
    /// "currently on since X". Shown on `VenuePremiumInfoScreen`;
    /// `null` on venues predating this field.
    @NullableTimestampConverter() DateTime? premiumSince,

    /// When the current premium period ends — set/extended only by
    /// `applyPaymentOutcome`'s `venue_premium` branch (functions/src/
    /// index.ts), never by the client (blocked in firestore.rules). A
    /// renewal purchased before expiry EXTENDS this (adds to the
    /// existing date) rather than resetting it from now — see that
    /// Cloud Function branch. `null` for venues never premium via a
    /// real payment (including admin-toggled-only venues).
    @NullableTimestampConverter() DateTime? premiumExpiresAt,

    /// True once the "N gün sonra bitir" reminder has been sent for
    /// the CURRENT [premiumExpiresAt] — stops `expireVenuePremium`'s
    /// (scheduled Cloud Function) reminder pass from refiring daily
    /// inside the 3-5-day window. Reset to `false` by
    /// `applyPaymentOutcome` on every new premium payment, so a
    /// renewed venue gets its own future reminder.
    @Default(false) bool premiumExpiryReminderSent,

    /// Whether `computeBirthdayMatches` (the daily birthday-offer
    /// matching Cloud Function) considers this venue at all — defaults
    /// to `category`'s membership in [kBirthdayEligibleVenueCategories]
    /// at creation time, owner-editable afterward from the create/edit
    /// form ONLY for categories in that set (every other category
    /// never shows the toggle, so this just stays `false` for them).
    @Default(false) bool birthdayNotificationsEnabled,

    /// Owner-set "current free seats" count (0-50), edited from the
    /// standalone seat-count sheet on `MyVenuesScreen` (NOT the
    /// create/edit form — this is meant for frequent, lightweight
    /// updates, not a full re-submit). Null means the owner has never
    /// turned this feature on — [SeatAvailabilityCard] on
    /// `VenueProfileScreen` renders nothing at all in that case, rather
    /// than showing a misleading "0 seats".
    int? availableSeats,

    /// When [availableSeats] was last written — always set together
    /// with it (`FieldValue.serverTimestamp()`), null exactly when
    /// [availableSeats] is null. Powers the "X dəq əvvəl yeniləndi"
    /// caption under the card.
    @NullableTimestampConverter() DateTime? seatsUpdatedAt,

    /// Owner's "Növbəni aktivləşdir/söndür" toggle for the walk-in
    /// waitlist feature (`venues/{id}/waitlist`) — false hides the
    /// "Sıraya yaz" button on `VenueProfileScreen`, but never affects
    /// entries already in the queue (they still see their own status
    /// and can still be called/seated normally).
    @Default(false) bool waitlistEnabled,
  }) = _Venue;

  factory Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);

  /// Convenience for the repository layer — Firestore doc ids live
  /// outside the document body, so this merges the id back in before
  /// handing off to the generated [Venue.fromJson].
  factory Venue.fromFirestore(String id, Map<String, dynamic> data) {
    return Venue.fromJson({...data, 'id': id});
  }

  bool isOwnedBy(String uid) => ownerId == uid;
}

/// The 3 [SeatAvailabilityCard] states, derived purely from
/// [Venue.availableSeats] — kept as a plain enum rather than inline
/// thresholds so the same "which color/label" logic isn't duplicated
/// anywhere else that might need it later.
enum SeatAvailabilityLevel { plenty, low, full }

extension SeatAvailabilityX on Venue {
  SeatAvailabilityLevel? get seatAvailabilityLevel {
    final seats = availableSeats;
    if (seats == null) return null;
    if (seats == 0) return SeatAvailabilityLevel.full;
    if (seats <= 5) return SeatAvailabilityLevel.low;
    return SeatAvailabilityLevel.plenty;
  }
}
