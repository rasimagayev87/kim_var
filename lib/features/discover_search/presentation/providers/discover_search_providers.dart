import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../profile/domain/entities/public_profile.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../data/repositories/firebase_discover_search_repository.dart';
import '../../domain/repositories/discover_search_repository.dart';

final discoverSearchRepositoryProvider = Provider<DiscoverSearchRepository>((ref) {
  return FirebaseDiscoverSearchRepository();
});

/// How long to wait after the last keystroke before actually querying
/// — avoids firing 3 Firestore queries per character while the user
/// is still typing.
const _kSearchDebounce = Duration(milliseconds: 300);

class DiscoverSearchState {
  final String query;
  final bool isSearching;
  final List<PublicProfile> users;
  final List<Venue> venues;

  const DiscoverSearchState({
    this.query = '',
    this.isSearching = false,
    this.users = const [],
    this.venues = const [],
  });

  bool get hasQuery => query.trim().isNotEmpty;

  DiscoverSearchState copyWith({
    String? query,
    bool? isSearching,
    List<PublicProfile>? users,
    List<Venue>? venues,
  }) {
    return DiscoverSearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      users: users ?? this.users,
      venues: venues ?? this.venues,
    );
  }
}

/// Backs the discover/search screen's search bar. Username is the
/// primary key (searched first, listed first — see
/// `DiscoverSearchRepository`'s own doc comment for why it alone needs
/// no backfill), name and venue matches run alongside it.
class DiscoverSearchController extends StateNotifier<DiscoverSearchState> {
  DiscoverSearchController(this._repository) : super(const DiscoverSearchState());

  final DiscoverSearchRepository _repository;
  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);

    if (query.trim().isEmpty) {
      state = state.copyWith(users: const [], venues: const [], isSearching: false);
      return;
    }

    _debounce = Timer(_kSearchDebounce, () => _runSearch(query));
  }

  /// Each of the 3 queries is caught independently — a `Future.wait`
  /// over all 3 together would fail the whole search (wiping out
  /// results from the other two, which may have succeeded) the moment
  /// any ONE of them throws, e.g. a security-rules gap on just the
  /// username query. Confirmed happening: `usernames`' rules only had
  /// `allow get`, not `allow list`, so the username query's
  /// permission-denied was silently blanking name/venue results too
  /// even though those were never actually broken.
  Future<void> _runSearch(String query) async {
    state = state.copyWith(isSearching: true);

    final byUsername = await _guarded(() => _repository.searchUsersByUsername(query), 'searchUsersByUsername');
    final byName = await _guarded(() => _repository.searchUsersByName(query), 'searchUsersByName');
    final venues = await _guarded(() => _repository.searchVenues(query), 'searchVenues');

    // The user may have kept typing while this was in flight — a
    // stale response for an earlier query landing after a newer one
    // would otherwise flicker the results backwards.
    if (state.query != query) return;

    final seen = <String>{};
    final users = <PublicProfile>[
      for (final user in [...byUsername, ...byName])
        if (seen.add(user.id)) user,
    ];

    state = state.copyWith(users: users, venues: venues, isSearching: false);
  }

  Future<List<T>> _guarded<T>(Future<List<T>> Function() query, String site) async {
    try {
      return await query();
    } catch (e, st) {
      logError('discover_search_providers.DiscoverSearchController.$site', e, st);
      return const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final discoverSearchControllerProvider =
    StateNotifierProvider.autoDispose<DiscoverSearchController, DiscoverSearchState>((ref) {
  return DiscoverSearchController(ref.watch(discoverSearchRepositoryProvider));
});
