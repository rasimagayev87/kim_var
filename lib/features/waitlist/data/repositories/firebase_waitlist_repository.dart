import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/waitlist_entry.dart';
import '../../domain/repositories/waitlist_repository.dart';

class FirebaseWaitlistRepository implements WaitlistRepository {
  FirebaseWaitlistRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _waitlist(String venueId) {
    return _firestore.collection('venues').doc(venueId).collection('waitlist');
  }

  @override
  Future<String> joinWaitlist({required String venueId, required String userId, required int partySize}) async {
    final ref = await _waitlist(venueId).add({
      'userId': userId,
      'partySize': partySize,
      'status': WaitlistEntryStatus.waiting.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Stream<WaitlistEntry?> watchMyEntry({required String venueId, required String userId}) {
    return _waitlist(venueId)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [WaitlistEntryStatus.waiting.name, WaitlistEntryStatus.called.name])
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : WaitlistEntry.fromFirestore(snap.docs.first.id, venueId, snap.docs.first.data()));
  }

  @override
  Stream<List<WaitlistEntry>> watchWaitingList(String venueId) {
    // Includes `called` alongside `waiting` — the owner's Növbə view
    // still needs to show a called entry (with its Gəldi/Gəlmədi
    // buttons) until it resolves to seated/no_show, even though it's
    // no longer counted in `queuePosition`.
    return _waitlist(venueId)
        .where('status', whereIn: [WaitlistEntryStatus.waiting.name, WaitlistEntryStatus.called.name])
        .orderBy('joinedAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => WaitlistEntry.fromFirestore(d.id, venueId, d.data())).toList());
  }

  @override
  Future<void> cancelEntry({required String venueId, required String entryId}) {
    return _waitlist(venueId).doc(entryId).update({'status': WaitlistEntryStatus.cancelled.name});
  }

  @override
  Future<void> callEntry({required String venueId, required String entryId}) {
    return _waitlist(venueId).doc(entryId).update({
      'status': WaitlistEntryStatus.called.name,
      'calledAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSeated({required String venueId, required String entryId}) {
    return _waitlist(venueId).doc(entryId).update({'status': WaitlistEntryStatus.seated.name});
  }

  @override
  Future<void> markNoShow({required String venueId, required String entryId}) {
    return _waitlist(venueId).doc(entryId).update({'status': WaitlistEntryStatus.noShow.name});
  }

  @override
  Future<void> removeEntry({required String venueId, required String entryId}) {
    return _waitlist(venueId).doc(entryId).update({'status': WaitlistEntryStatus.cancelled.name});
  }

  @override
  Future<void> setWaitlistEnabled({required String venueId, required bool enabled}) {
    return _firestore.collection('venues').doc(venueId).update({'waitlistEnabled': enabled});
  }

  @override
  Future<bool> hasAnyEntry(String venueId) async {
    final snap = await _waitlist(venueId).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
