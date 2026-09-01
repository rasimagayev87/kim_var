import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The venues published for THIS user's birthday today.
///
/// ── Why there is no "is it my birthday" check on this device ───────
///
/// There is nothing here that reads a birth date, compares a month and
/// a day, or asks whether the section should be shown. The server
/// answers that question by writing (or not writing)
/// `users/{uid}/birthdayFeed/{dateKey}` at 13:00, and
/// `firestore.rules` gives it `allow write: if false` so no client can
/// manufacture one. A user whose birthday is not today has no document
/// to read, and the section renders nothing.
///
/// That is the whole enforcement, and it is deliberate: `birthDate`
/// lives in `users/{uid}/private/data` and never reaches another
/// device, so a client-side check would have had nothing correct to
/// check against anyway.
class BirthdayFeed {
  const BirthdayFeed({required this.venueIds, required this.highlightVenueIds});

  /// Every venue publishing a birthday campaign for this user today,
  /// best first — the "Ad günü fürsətləri" list.
  final List<String> venueIds;

  /// The up-to-three the 13:00 notification named, one per category.
  final List<String> highlightVenueIds;

  bool get isEmpty => venueIds.isEmpty;
}

/// `YYYY-MM-DD` in Asia/Baku — the document id `publishBirthdayCampaigns`
/// writes under.
///
/// Azerbaijan has been a fixed UTC+4 with no DST since 2016, and this
/// is a "which day is it right now" question rather than a historical
/// one, so the fixed offset is exact here. (The SERVER cannot take this
/// shortcut: it also reads birth dates from 1987, when the offset was
/// different — see `functions/src/birthday.ts`.)
String bakuDateKeyNow([DateTime? now]) {
  final baku = (now ?? DateTime.now().toUtc()).toUtc().add(
    const Duration(hours: 4),
  );
  final month = baku.month.toString().padLeft(2, '0');
  final day = baku.day.toString().padLeft(2, '0');
  return '${baku.year}-$month-$day';
}

final myBirthdayFeedProvider = FutureProvider.autoDispose<BirthdayFeed?>((
  ref,
) async {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('birthdayFeed')
      .doc(bakuDateKeyNow())
      .get();

  final data = snap.data();
  if (data == null) return null;

  final venueIds = (data['venueIds'] as List<dynamic>? ?? const [])
      .map((v) => v.toString())
      .toList();
  if (venueIds.isEmpty) return null;

  return BirthdayFeed(
    venueIds: venueIds,
    highlightVenueIds: (data['highlightVenueIds'] as List<dynamic>? ?? const [])
        .map((v) => v.toString())
        .toList(),
  );
});
