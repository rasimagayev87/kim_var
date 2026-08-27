import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../profile/domain/entities/public_profile.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/repositories/discover_search_repository.dart';

/// U+F8FF (Unicode's highest single code point below the private-
/// use area) — appending it to a lowercased query and using it as
/// the range's upper bound is the standard Firestore "prefix"
/// search trick: any string starting with [query] sorts strictly
/// between query itself and query+U+F8FF lexicographically.
const _kPrefixRangeEnd = '\uf8ff';

class FirebaseDiscoverSearchRepository implements DiscoverSearchRepository {
  FirebaseDiscoverSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames => _firestore.collection('usernames');
  CollectionReference<Map<String, dynamic>> get _venues => _firestore.collection('venues');

  @override
  Future<List<PublicProfile>> searchUsersByUsername(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = await _usernames
        .orderBy(FieldPath.documentId)
        .startAt([q])
        .endAt(['$q$_kPrefixRangeEnd'])
        .limit(limit)
        .get();

    final uids = snap.docs.map((d) => d.data()['uid'] as String?).whereType<String>().toList();
    return _fetchProfiles(uids);
  }

  @override
  Future<List<PublicProfile>> searchUsersByName(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = await _users
        .orderBy('nameLower')
        .startAt([q])
        .endAt(['$q$_kPrefixRangeEnd'])
        .limit(limit)
        .get();

    return snap.docs.map((d) => _profileFromDoc(d.id, d.data())).toList();
  }

  @override
  Future<List<Venue>> searchVenues(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = await _venues
        .where('status', isEqualTo: 'approved')
        .orderBy('nameLower')
        .startAt([q])
        .endAt(['$q$_kPrefixRangeEnd'])
        .limit(limit)
        .get();

    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  /// Resolves matched uids to profiles with a plain `Future.wait` of
  /// individual `get()`s (same shape `FirebasePostRepository.
  /// _watchMirroredPosts` already uses for "id list → docs") rather
  /// than a `whereIn` query, so the result order matches the
  /// prefix-match order the caller queried for instead of whatever
  /// order `whereIn` would return.
  Future<List<PublicProfile>> _fetchProfiles(List<String> uids) async {
    if (uids.isEmpty) return [];
    final docs = await Future.wait(uids.map((id) => _users.doc(id).get()));
    return docs
        .where((d) => d.exists)
        .map((d) => _profileFromDoc(d.id, d.data()!))
        .toList();
  }

  PublicProfile _profileFromDoc(String id, Map<String, dynamic> data) {
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    return PublicProfile(
      id: id,
      name: '$firstName $lastName'.trim(),
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      identityVerified: data['identityVerified'] as bool? ?? false,
      premium: data['premium'] as bool? ?? false,
    );
  }
}
