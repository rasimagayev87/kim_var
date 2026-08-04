import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue.freezed.dart';
part 'venue.g.dart';

/// Self-service-submitted local businesses (Kəşf et → Məkanlar).
/// Deliberately no review/rating fields — no review system exists yet,
/// and this app never shows fabricated numbers.
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
  other,
}

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
  VenueCategory.other: Icons.category_outlined,
};

IconData venueCategoryIcon(VenueCategory category) => _venueCategoryIcons[category]!;

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
      'schedule': {for (final entry in schedule.entries) '${entry.key}': entry.value?.toMap()},
    };
  }

  static OpeningHours fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OpeningHours();
    final rawSchedule = map['schedule'] as Map?;
    final schedule = <int, DayHours?>{
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: DayHours.fromMap((rawSchedule?['$weekday'] as Map?)?.cast<String, dynamic>()),
    };
    return OpeningHours(is24h: map['is24h'] as bool? ?? false, schedule: schedule);
  }
}

class VenueCategoryConverter implements JsonConverter<VenueCategory, String?> {
  const VenueCategoryConverter();

  @override
  VenueCategory fromJson(String? json) =>
      VenueCategory.values.firstWhere((c) => c.name == json, orElse: () => VenueCategory.other);

  @override
  String toJson(VenueCategory category) => category.name;
}

class OpeningHoursConverter implements JsonConverter<OpeningHours, Map<String, dynamic>?> {
  const OpeningHoursConverter();

  @override
  OpeningHours fromJson(Map<String, dynamic>? json) => OpeningHours.fromMap(json);

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
  Object? toJson(DateTime? date) => date == null ? null : Timestamp.fromDate(date);
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

    /// Defaults to 'active' — no moderation queue exists yet, so every
    /// submitted venue is immediately visible. Kept as a string (not a
    /// bool) specifically so a future 'pending'/'approved'/'rejected'
    /// moderation flow is a value change here, not a schema migration.
    @Default('active') String status,

    /// Reserved for a future admin-verification badge — nothing sets
    /// this true yet, so it never renders today.
    @Default(false) bool verified,

    /// Reserved for the favorites feature (`users/{uid}/favorites`) —
    /// a denormalized counter nothing increments yet.
    @Default(0) int favoriteCount,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
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
