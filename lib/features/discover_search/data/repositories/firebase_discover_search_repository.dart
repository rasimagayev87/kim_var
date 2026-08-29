import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/utils/app_logger.dart';
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

  /// Server-side (Düzəliş Prompt 5) — was a raw `users.orderBy
  /// ('nameLower')...` LIST query, which `firestore.rules`' `allow
  /// list: if false` on `users` (Düzəliş Prompt 4 / RT-25) has denied
  /// outright since that change; this was silently broken (never
  /// deployed, so no real user hit it) until fixed here. The
  /// `searchUsersByName` callable (functions/src/index.ts) also
  /// filters out blocked pairs, in either direction — something this
  /// method never did before either.
  @override
  Future<List<PublicProfile>> searchUsersByName(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchUsersByName');
      final result = await callable.call<Map<String, dynamic>>({'query': q});
      final raw = (result.data['profiles'] as List).cast<dynamic>();
      return raw.map((e) => _profileFromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e, st) {
      logError('firebase_discover_search_repository.searchUsersByName', e, st);
      return [];
    }
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

    return snap.docs
        .map((d) {
          try {
            return Venue.fromFirestore(d.id, d.data());
          } catch (e, st) {
            // See `FirebaseVenueRepository._safeVenue`'s doc comment —
            // same per-document isolation.
            logError('firebase_discover_search_repository.Venue.fromFirestore(${d.id})', e, st);
            return null;
          }
        })
        .whereType<Venue>()
        .toList();
  }

  /// Resolves matched uids to profiles with a plain `Future.wait` of
  /// individual `get()`s (same shape `FirebasePostRepository.
  /// _watchMirroredPosts` already uses for "id list → docs") rather
  /// than a `whereIn` query, so the result order matches the
  /// prefix-match order the caller queried for instead of whatever
  /// order `whereIn` would return.
  ///
  /// Each `get()` is caught INDIVIDUALLY (Düzəliş Prompt 5) — a blocked
  /// pair's `users/{uid}` read now throws `permission-denied`
  /// (`firestore.rules`, K-3); with `Future.wait` erroring as a whole
  /// batch, ONE blocked match used to wipe every OTHER, unrelated
  /// result out of the search too. Excluding just that one uid is the
  /// correct behavior — "bloklanan istifadəçi axtarışda görünməməlidir"
  /// without breaking the rest of the query.
  Future<List<PublicProfile>> _fetchProfiles(List<String> uids) async {
    if (uids.isEmpty) return [];
    final docs = await Future.wait(
      uids.map((id) async {
        try {
          return await _users.doc(id).get();
        } on FirebaseException {
          return null;
        }
      }),
    );
    return docs
        .whereType<DocumentSnapshot<Map<String, dynamic>>>()
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

  /// Same shape as [_profileFromDoc], for the `searchUsersByName`
  /// callable's plain-map response instead of a Firestore document.
  PublicProfile _profileFromMap(Map<String, dynamic> data) {
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    return PublicProfile(
      id: data['uid'] as String,
      name: '$firstName $lastName'.trim(),
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      identityVerified: data['identityVerified'] as bool? ?? false,
      premium: data['premium'] as bool? ?? false,
    );
  }
}
