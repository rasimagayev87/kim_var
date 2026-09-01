import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../profile/domain/entities/public_profile.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../data/repositories/firebase_discover_search_repository.dart';
import '../../domain/repositories/discover_search_repository.dart';

final discoverSearchRepositoryProvider = Provider<DiscoverSearchRepository>((
  ref,
) {
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
  DiscoverSearchController(this._repository)
    : super(const DiscoverSearchState());

  final DiscoverSearchRepository _repository;
  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);

    if (query.trim().isEmpty) {
      state = state.copyWith(
        users: const [],
        venues: const [],
        isSearching: false,
      );
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
  /// Three independent lookups, fired TOGETHER and rendered as each
  /// one lands.
  ///
  /// They used to be awaited in sequence — username, then name, then
  /// venues — so the wait was the sum of three round trips rather than
  /// the longest one, and nothing appeared until all three were done.
  ///
  /// Results are merged incrementally rather than through a single
  /// `Future.wait`: usernames usually resolve first, and showing them
  /// immediately is better than holding a finished list back until the
  /// slowest query returns. `isSearching` stays true until the last one
  /// lands, so the spinner keeps running under whatever is already on
  /// screen.
  Future<void> _runSearch(String query) async {
    state = state.copyWith(
      isSearching: true,
      users: const [],
      venues: const [],
    );

    // Every callback re-checks the query: the user keeps typing, and a
    // response for an abandoned query must never overwrite the current
    // one. There is no way to cancel an in-flight callable, so the
    // result is discarded on arrival instead.
    var byUsername = <PublicProfile>[];
    var byName = <PublicProfile>[];

    void mergeUsers() {
      final seen = <String>{};
      state = state.copyWith(
        users: [
          for (final user in [...byUsername, ...byName])
            if (seen.add(user.id)) user,
        ],
      );
    }

    final usernameFuture =
        _guarded(
          () => _repository.searchUsersByUsername(query),
          'searchUsersByUsername',
        ).then((r) {
          if (state.query != query) return;
          byUsername = r;
          mergeUsers();
        });

    final nameFuture =
        _guarded(
          () => _repository.searchUsersByName(query),
          'searchUsersByName',
        ).then((r) {
          if (state.query != query) return;
          byName = r;
          mergeUsers();
        });

    final venuesFuture =
        _guarded(() => _repository.searchVenues(query), 'searchVenues').then((
          r,
        ) {
          if (state.query != query) return;
          state = state.copyWith(venues: r);
        });

    await Future.wait([usernameFuture, nameFuture, venuesFuture]);

    if (state.query != query) return;
    state = state.copyWith(isSearching: false);
  }

  Future<List<T>> _guarded<T>(
    Future<List<T>> Function() query,
    String site,
  ) async {
    try {
      return await query();
    } catch (e, st) {
      logError(
        'discover_search_providers.DiscoverSearchController.$site',
        e,
        st,
      );
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
    StateNotifierProvider.autoDispose<
      DiscoverSearchController,
      DiscoverSearchState
    >((ref) {
      return DiscoverSearchController(
        ref.watch(discoverSearchRepositoryProvider),
      );
    });
