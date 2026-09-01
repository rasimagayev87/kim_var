import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/private_data_ref.dart';

/// A visitor entry: who viewed the profile, and when. Display info
/// (name/photo) is resolved separately per-uid via [publicProfileProvider]
/// — this feature only owns the "who + when" list, not a duplicate copy
/// of profile data that could drift stale.
class ProfileVisit {
  final String viewerId;
  final DateTime viewedAt;

  const ProfileVisit({required this.viewerId, required this.viewedAt});
}

/// Records that the signed-in user viewed [viewedUid]'s profile. A
/// `FutureProvider.autoDispose.family` rather than a plain function so
/// `UserProfileScreen` (a stateless ConsumerWidget, no initState) can
/// fire this exactly once per fresh navigation into a profile by just
/// watching it — autoDispose tears down and re-fires on the next visit
/// instead of caching forever.
final recordProfileVisitProvider = FutureProvider.autoDispose
    .family<void, String>((ref, viewedUid) async {
      final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null || myUid == viewedUid) return;

      // "Gizli baxış" (VIP incognito browsing) — a viewer with this on
      // leaves no trace, so the write below is skipped entirely rather
      // than written-then-hidden. See `PrivacySettings.incognitoBrowsingEnabled`
      // (`users/{uid}/private/data` since Düzəliş Prompt 4).
      final myDoc = await privateDataRef(myUid).get();
      final incognito =
          myDoc.data()?['incognitoBrowsingEnabled'] as bool? ?? false;
      if (incognito) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(viewedUid)
          .collection('profileViews')
          .doc(myUid)
          .set({'viewerId': myUid, 'viewedAt': FieldValue.serverTimestamp()});
    });

/// Streams the signed-in user's own `lastVisitorsCheckedAt` field — null
/// if the visitors screen has never been opened, meaning every visit in
/// the window still counts as "new".
final lastVisitorsCheckedAtProvider = StreamProvider.autoDispose<DateTime?>((
  ref,
) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(null);
  return privateDataRef(myUid).snapshots().map(
    (snap) => (snap.data()?['lastVisitorsCheckedAt'] as Timestamp?)?.toDate(),
  );
});

/// Marks the visitors list as caught-up as of now — fired once when
/// [ProfileVisitorsScreen] opens, mirroring [recordProfileVisitProvider]'s
/// "watch to fire once per fresh navigation" shape.
final markVisitorsCheckedProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return;
  await privateDataRef(myUid).set({
    'lastVisitorsCheckedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
});

const _kProfileVisitorsWindow = Duration(days: 30);

/// Live list of everyone who viewed [uid]'s profile in the last 30
/// days, most recent first.
final profileVisitorsProvider = StreamProvider.autoDispose
    .family<List<ProfileVisit>, String>((ref, uid) {
      final cutoff = DateTime.now().subtract(_kProfileVisitorsWindow);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profileViews')
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('viewedAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((doc) {
              final data = doc.data();
              return ProfileVisit(
                viewerId: data['viewerId'] as String,
                viewedAt:
                    (data['viewedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList(),
          );
    });

/// Live "new since last check" count for the signed-in user's own
/// visitors — the badge shown on the footprint icon before it's opened.
/// Falls back to the full window's count when [lastVisitorsCheckedAt]
/// hasn't been set yet (never opened before).
final newProfileVisitorsCountProvider = Provider.autoDispose<int>((ref) {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return 0;

  final visitors =
      ref.watch(profileVisitorsProvider(myUid)).valueOrNull ?? const [];
  final lastChecked = ref.watch(lastVisitorsCheckedAtProvider).valueOrNull;
  if (lastChecked == null) return visitors.length;
  return visitors.where((v) => v.viewedAt.isAfter(lastChecked)).length;
});
