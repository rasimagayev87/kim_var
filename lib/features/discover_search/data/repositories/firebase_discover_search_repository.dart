import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../profile/domain/entities/public_profile.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/repositories/discover_search_repository.dart';

import '../../../../core/utils/callables.dart';

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

  CollectionReference<Map<String, dynamic>> get _venues =>
      _firestore.collection('venues');

  @override
  /// Server-side (P0 / H-6) — was a raw `usernames` LIST query, which
  /// `firestore.rules` now denies. That collection is a complete
  /// `username → uid` index, so a listable version of it re-opened the
  /// mass-enumeration path RT-25 closed on `users` itself, just one hop
  /// further out. The callable also applies a bidirectional block
  /// filter, which this query never did.
  ///
  /// Single-document `get`s on `usernames` are unaffected and stay open
  /// (deep links, availability checks) — see the rule's own comment.
  @override
  Future<List<PublicProfile>> searchUsersByUsername(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'searchUsersByUsername',
        options: callableOptions(),
      );
      final result = await callable.call<Map<String, dynamic>>({'query': q});
      final raw = (result.data['profiles'] as List).cast<dynamic>();
      return raw
          .map((e) => _profileFromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      logError(
        'firebase_discover_search_repository.searchUsersByUsername',
        e,
        st,
      );
      return [];
    }
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
  Future<List<PublicProfile>> searchUsersByName(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'searchUsersByName',
        options: callableOptions(),
      );
      final result = await callable.call<Map<String, dynamic>>({'query': q});
      final raw = (result.data['profiles'] as List).cast<dynamic>();
      return raw
          .map((e) => _profileFromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
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
            logError(
              'firebase_discover_search_repository.Venue.fromFirestore(${d.id})',
              e,
              st,
            );
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
  /// Builds a [PublicProfile] from the plain-map response both
  /// user-search callables return. The former Firestore-document
  /// variant (and the per-uid `get()` fan-out it fed) went away with
  /// P0 / H-6: neither search reads `users` documents from the client
  /// any more, so the block-aware per-uid error handling that fan-out
  /// needed now lives server-side in the callables themselves.
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
