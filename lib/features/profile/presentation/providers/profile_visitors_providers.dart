import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final recordProfileVisitProvider = FutureProvider.autoDispose.family<void, String>((ref, viewedUid) async {
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null || myUid == viewedUid) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(viewedUid)
      .collection('profileViews')
      .doc(myUid)
      .set({
    'viewerId': myUid,
    'viewedAt': FieldValue.serverTimestamp(),
  });
});

const _kProfileVisitorsWindow = Duration(days: 30);

/// Live list of everyone who viewed [uid]'s profile in the last 30
/// days, most recent first.
final profileVisitorsProvider = StreamProvider.autoDispose.family<List<ProfileVisit>, String>((ref, uid) {
  final cutoff = DateTime.now().subtract(_kProfileVisitorsWindow);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('profileViews')
      .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .orderBy('viewedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final data = doc.data();
            return ProfileVisit(
              viewerId: data['viewerId'] as String,
              viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList());
});
