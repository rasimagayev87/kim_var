import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/account_status_checker.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/private_data_ref.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/location_failure.dart';
import '../../domain/nearby_user.dart';

import '../../../../core/utils/callables.dart';

final locationControllerProvider =
    StateNotifierProvider<LocationController, AsyncValue<Position>>((ref) {
      // Same fix as chatListControllerProvider/notificationListControllerProvider
      // — LocationController isn't autoDispose, so without this watch its
      // live GPS stream (which keeps writing `online: true`/lat/lng to
      // whatever uid is CURRENTLY signed in on every position update)
      // would otherwise keep running against a session that's already
      // moved on, instead of starting clean for whoever just signed in.
      ref.watch(authStateProvider);
      return LocationController()..refresh();
    });

class LocationController extends StateNotifier<AsyncValue<Position>> {
  LocationController({FirebaseFirestore? firestore, fb.FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? fb.FirebaseAuth.instance,
      super(const AsyncValue.loading());

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  StreamSubscription<Position>? _liveSubscription;

  /// Driven by the Xəritə və Lokasiya → GPS dəqiqliyi setting (see
  /// [applyAccuracy]). Defaults to high until that preference loads.
  LocationAccuracy _accuracy = LocationAccuracy.high;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_getPosition);
    final position = state.valueOrNull;
    if (position != null) {
      await _writePosition(position);
      _startLiveUpdates();
    }
  }

  /// Applies a GPS accuracy preference change immediately — restarts
  /// the live stream so it takes effect without needing an app
  /// restart, matching the general rule that Settings toggles must
  /// have a real, live effect.
  void applyAccuracy(LocationAccuracy accuracy) {
    if (_accuracy == accuracy) return;
    _accuracy = accuracy;
    if (state.valueOrNull != null) {
      _startLiveUpdates();
    }
  }

  /// Completed once the LOCATION permission request has resolved, so
  /// the notification request can queue behind it.
  ///
  /// Android shows one permission dialog at a time and silently drops
  /// whichever asks second. Originally both were fired in the same
  /// frame (`HomeScreen.initState` → `syncSubscriptions`, and
  /// `DiscoverTab.build` → this controller), and location lost — a
  /// fresh install got no location prompt at all and the map sat on a
  /// spinner.
  ///
  /// Location goes FIRST, deliberately. Discover is the landing screen
  /// and cannot draw anything without a position, while notifications
  /// affect nothing the user is currently looking at. Ordering it the
  /// other way round meant every first launch stared at a spinner
  /// waiting for a dialog about something else.
  static Completer<void> _locationPermissionSettled = Completer<void>();

  /// Awaited by the notification flow — see `syncSubscriptions`.
  ///
  /// The 5s ceiling is a safety net, not a delay: this completes as
  /// soon as the location dialog is answered. It only matters if that
  /// dialog never resolves, and notifications must not be lost to a
  /// stuck location flow.
  static Future<void> awaitLocationPermission() {
    return _locationPermissionSettled.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  static void _markLocationPermissionSettled() {
    if (!_locationPermissionSettled.isCompleted)
      _locationPermissionSettled.complete();
  }

  Future<Position> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _markLocationPermissionSettled();
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _markLocationPermissionSettled();
        throw const LocationException(LocationFailure.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _markLocationPermissionSettled();
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }
    // Whatever the answer, the dialog is gone — notifications may ask now.
    _markLocationPermissionSettled();

    // Now that permission is actually held, the OS's cached fix can be
    // read and painted while the real one is still being acquired.
    // Seeding BEFORE this point (where it used to be) always failed:
    // `getLastKnownPosition` performs its own permission check, and at
    // the top of `refresh()` the permission has not been requested yet,
    // so it threw every time and delivered nothing.
    unawaited(_seedFromLastKnown());

    // A cold GPS can take a minute to reach a high-accuracy fix, and
    // `getCurrentPosition` has no default deadline — which is how a
    // first launch ended up on an unbounded spinner. Fail fast instead,
    // and let the live stream refine afterwards.
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: _accuracy,
        timeLimit: const Duration(seconds: 15),
      ),
    );
  }

  /// Paints the map from the OS's cached fix while the real one is
  /// still being acquired.
  ///
  /// `getLastKnownPosition` returns immediately and costs nothing — it
  /// reads what the platform already has. The app never used it, so
  /// every launch waited for a full fix before showing anything, even
  /// when a perfectly good position from a minute ago was sitting
  /// there. Only used to fill an EMPTY state; it never overwrites a
  /// live fix.
  Future<void> _seedFromLastKnown() async {
    if (state.valueOrNull != null) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && state.valueOrNull == null) {
        state = AsyncValue.data(last);
      }
    } catch (e, st) {
      logError('location_providers.seedFromLastKnown', e, st);
    }
  }

  /// Streams position updates in the background so the user's
  /// coordinates in Firestore (and therefore how they appear to
  /// others on the map) stay live while the app is open.
  void _startLiveUpdates() {
    _liveSubscription?.cancel();
    _liveSubscription =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: _accuracy,
            distanceFilter: 25, // metres — avoids writing on every tiny jitter
          ),
        ).listen((position) {
          state = AsyncValue.data(position);
          _writePosition(position);
        });
  }

  /// `lat`/`lng` live on `users/{uid}/private/data` (Düzəliş Prompt 4 /
  /// K-1) — a raw coordinate is exactly the kind of field that must
  /// never be world-readable.
  ///
  /// Does NOT write `online`/`lastSeen` (Düzəliş Prompt 5 / RT-24) —
  /// this used to write both fields itself, independently of
  /// [PresenceController], which was exactly the kind of second,
  /// unaccounted-for write path that made the now-removed
  /// `showOnlineStatus` toggle unreliable (any single-purpose gate on
  /// ONE writer means nothing once a second writer bypasses it
  /// entirely). Presence now has exactly one writer —
  /// `PresenceController`'s own heartbeat (every 25s while
  /// foregrounded, started from `HomeScreen`, active for the whole
  /// session `LocationController` ever runs during) — so `lastSeen`
  /// stays just as fresh for `findNearbyUsers`' scan without this
  /// controller needing to touch it at all.
  Future<void> _writePosition(Position position) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await privateDataRef(uid, firestore: _firestore).set({
        'lat': position.latitude,
        'lng': position.longitude,
      }, SetOptions(merge: true));
    } catch (e) {
      // Same reasoning as PresenceController's own `_write` — a
      // deleted/banned account's cached token would otherwise keep
      // retrying this write on every ≥25m position update forever.
      // `handleWritePermissionDenied` tells a genuine deletion/ban
      // apart from a transient race and, only for the former, forces
      // sign-out AND stops the live GPS subscription.
      if (await handleWritePermissionDenied(e)) {
        _liveSubscription?.cancel();
        _liveSubscription = null;
      }
    }
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}

/// All 6 distance options are free for every user — only the two
/// non-distance modes, Ölkə üzrə/Dünya üzrə (see [DiscoverRadiusMode]),
/// remain VIP-only. That lock is hardcoded at each call site (not
/// derived from this list), since it isn't a km value.
///
/// Sourced from Remote Config's `radius_options_json` (see
/// `AppConfig.radiusOptionsKm`/`FirebaseAppConfigRepository`) — set once
/// in `main()` right after the config repository's `init()` resolves,
/// same as [kDefaultRadiusOptionsKm]/[kExtraRadiusOptionsKm] below.
/// Deliberately a plain mutable top-level list rather than threading
/// `ref` through the ~15 call sites across `discover_tab.dart`,
/// `privacy_security_screen.dart`, and `create_venue_screen.dart` that
/// already reference these by name: a changed radius list isn't an
/// emergency kill-switch value the way `maintenance_mode_enabled`/
/// `force_update_enabled` are, so "picks up on next app start" is an
/// acceptable, explicitly-chosen trade-off for the simpler wiring. The
/// literal default below is what every one of those call sites already
/// saw before this became remote-configurable, so a build that somehow
/// runs before `main()`'s assignment (e.g. a widget test) behaves
/// identically to before this field existed.
List<double> kRadiusOptionsKm = const [0.1, 0.5, 1, 5, 10, 30];

/// The 3 options shown in the "Daha çox" panel alongside Ölkə üzrə/
/// Dünya üzrə — free, same as [kDefaultRadiusOptionsKm]. Derived from
/// [kRadiusOptionsKm] by [applyRemoteRadiusOptions] the same way it
/// always was, just re-derived from the remote list instead of a
/// hardcoded one.
List<double> kExtraRadiusOptionsKm = const [5, 10, 30];

/// The 3 options shown in the always-visible row — everything else
/// (5/10/30 km, plus Ölkə/Dünya) lives behind the "Daha çox" trigger.
List<double> kDefaultRadiusOptionsKm = const [0.1, 0.5, 1];

/// Re-derives [kRadiusOptionsKm]/[kDefaultRadiusOptionsKm]/
/// [kExtraRadiusOptionsKm] from a freshly-resolved [AppConfig.radiusOptionsKm].
/// Call once from `main()` after the app-config repository's `init()`
/// resolves. A list shorter than 3 entries is treated as malformed and
/// ignored (keeps whatever was there before) — the always-visible row
/// needs at least 3 options to render sensibly.
void applyRemoteRadiusOptions(List<double> remoteOptions) {
  if (remoteOptions.length < 3) return;
  kRadiusOptionsKm = remoteOptions;
  kDefaultRadiusOptionsKm = remoteOptions.take(3).toList();
  kExtraRadiusOptionsKm = remoteOptions.skip(3).toList();
}

/// How often [_pollNearbyCandidates]/[_pollDiscoverCandidates] re-fetch
/// — Düzəliş Prompt 4 replaced the old real-time `.snapshots()` listener
/// (which needed every candidate's raw fields client-side to filter
/// Ghost Mode/visibility radius/gender) with a server-side callable, so
/// every mode is now pull-based. Sourced from Remote Config's
/// `nearby_refresh_seconds` (`AppConfig.nearbyRefreshSeconds`), same
/// `main()`-assignment convention as [applyRemoteRadiusOptions] — see
/// [applyRemoteNearbyRefreshSeconds].
int kNearbyRefreshSeconds = 45;

/// Call once from `main()` after the app-config repository's `init()`
/// resolves, mirroring [applyRemoteRadiusOptions]. A non-positive value
/// is treated as malformed and ignored — the poll loop would otherwise
/// spin with no delay at all.
void applyRemoteNearbyRefreshSeconds(int remoteSeconds) {
  if (remoteSeconds <= 0) return;
  kNearbyRefreshSeconds = remoteSeconds;
}

/// Which of the 8 "Kəşf et" view modes is active: a distance ring
/// ([km] set), Ölkə üzrə, or Dünya üzrə. Only one at a time — country
/// and world aren't "infinite radius", they're genuinely different
/// queries (see [nearbyUsersProvider]).
enum DiscoverRadiusMode { distance, country, world }

class DiscoverRadiusSelection {
  final DiscoverRadiusMode mode;
  final double? km;

  const DiscoverRadiusSelection.distance(this.km)
    : mode = DiscoverRadiusMode.distance;
  const DiscoverRadiusSelection.country()
    : mode = DiscoverRadiusMode.country,
      km = null;
  const DiscoverRadiusSelection.world()
    : mode = DiscoverRadiusMode.world,
      km = null;

  @override
  bool operator ==(Object other) =>
      other is DiscoverRadiusSelection && other.mode == mode && other.km == km;

  @override
  int get hashCode => Object.hash(mode, km);
}

final selectedDiscoverModeProvider = StateProvider<DiscoverRadiusSelection>(
  (ref) => const DiscoverRadiusSelection.distance(1.0),
);

/// Mirrors [selectedDiscoverModeProvider] onto `users/{uid}/private/data`
/// as `discoverRadiusMode`/`discoverRadiusKm` — the ONLY reason this
/// exists is so server-side notification fanout
/// (`resolveNotifyCandidates`/`computeBirthdayMatches` in
/// `functions/src/index.ts`) can see it: a venue's own audience radius
/// was never meant to be the sole filter for who gets pinged about it
/// — the recipient's own chosen radius is always the other half (a
/// venue with a 30 km/Ölkə/Dünya audience must not reach someone who
/// has personally dialed their own radius down to 1 km). The one
/// exception is `independentArtist` follows, which bypass this on
/// purpose (see `resolveNotifyCandidates`'s own doc comment) — a
/// follower wants that venue's posts regardless of distance.
///
/// Watched from [DiscoverTab] (`ref.watch(...)` in its `build`, value
/// discarded) rather than tied to [LocationController] — that class
/// predates having a [Ref] to read this from, and duplicating its own
/// Firestore-write plumbing here isn't worth avoiding one extra
/// `ref.watch` call at the one place this actually needs to be alive.
/// `fireImmediately: true` means even a user who never touches the
/// radius picker still gets today's default (1 km) written once,
/// instead of leaving the field permanently absent (which would
/// silently exempt them from every recipient-radius check below).
final discoverRadiusPersistenceProvider = Provider<void>((ref) {
  ref.listen<DiscoverRadiusSelection>(selectedDiscoverModeProvider, (
    previous,
    next,
  ) {
    if (previous == next) return;
    _persistDiscoverRadius(next);
  }, fireImmediately: true);
});

void _persistDiscoverRadius(DiscoverRadiusSelection selection) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  unawaited(
    privateDataRef(uid)
        .set({
          'discoverRadiusMode': switch (selection.mode) {
            DiscoverRadiusMode.distance => 'distance',
            DiscoverRadiusMode.country => 'country',
            DiscoverRadiusMode.world => 'world',
          },
          'discoverRadiusKm': selection.km,
        }, SetOptions(merge: true))
        .catchError((e, st) {
          logError('location_providers._persistDiscoverRadius', e, st);
        }),
  );
}

/// Gender filter for the discover map/cards. Matches the free-text
/// `gender` values ('Kişi' / 'Qadın') already written to Firestore
/// by the profile edit screen.
///
/// [all] is free for everyone; picking [male]/[female] is VIP-only —
/// gated client-side in `discover_tab.dart`'s `_showGenderFilterSheet`
/// (same `isPremiumProvider`/`showPremiumUpsellSheet` pattern as the
/// Ölkə/Dünya radius lock). Enforced server-side too now (Düzəliş
/// Prompt 4 — `gender` moved off the public doc, so filtering by it can
/// only happen inside `findNearbyUsers`/`getDiscoverCandidates`, which
/// also closes the old "a modified client just sets this directly"
/// bypass this doc comment used to warn about.
enum GenderFilter { all, male, female }

final selectedGenderFilterProvider = StateProvider<GenderFilter>(
  (ref) => GenderFilter.all,
);

/// Wire value `findNearbyUsers`/`getDiscoverCandidates` (functions/src/
/// index.ts, `matchesGenderFilter`) understand — `null` means no filter.
String? _genderFilterWireValue(GenderFilter filter) => switch (filter) {
  GenderFilter.all => null,
  GenderFilter.male => 'male',
  GenderFilter.female => 'female',
};

/// One Discover/nearby candidate as returned by `findNearbyUsers`/
/// `getDiscoverCandidates` — both callables already enforce Ghost Mode,
/// visibility radius, the gender filter, and blocked pairs
/// server-side, so nothing here needs re-filtering client-side.
/// `lat`/`lng` are grid-rounded (~100m, anti-averaging) marker
/// positions, never a candidate's exact coordinates.
/// [distanceMeters] is only ever populated for distance-mode
/// (`findNearbyUsers`) — computed server-side from the raw, unrounded
/// coordinates before rounding.
class _RemoteCandidate {
  final String uid;
  final String? username;
  final String firstName;
  final String lastName;
  final String bio;
  final String? photoUrl;
  final bool online;
  final DateTime? lastSeen;
  final int? age;
  final double? lat;
  final double? lng;
  final double? distanceMeters;

  const _RemoteCandidate({
    required this.uid,
    this.username,
    this.firstName = '',
    this.lastName = '',
    this.bio = '',
    this.photoUrl,
    this.online = false,
    this.lastSeen,
    this.age,
    this.lat,
    this.lng,
    this.distanceMeters,
  });

  factory _RemoteCandidate.fromMap(Map<String, dynamic> raw) {
    final lastSeenMs = raw['lastSeen'] as num?;
    return _RemoteCandidate(
      uid: raw['uid'] as String,
      username: raw['username'] as String?,
      firstName: raw['firstName'] as String? ?? '',
      lastName: raw['lastName'] as String? ?? '',
      bio: raw['bio'] as String? ?? '',
      photoUrl: raw['photoUrl'] as String?,
      online: raw['online'] as bool? ?? false,
      lastSeen: lastSeenMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSeenMs.toInt()),
      age: (raw['age'] as num?)?.toInt(),
      lat: (raw['lat'] as num?)?.toDouble(),
      lng: (raw['lng'] as num?)?.toDouble(),
      distanceMeters: (raw['distanceMeters'] as num?)?.toDouble(),
    );
  }
}

/// Backs the distance-mode "yaxınlıqdakılar" feed — replaces the old
/// direct `_nearbyCandidatesProvider` Firestore stream, which read
/// every online user's raw document (including, pre-Prompt-4, their
/// exact `lat`/`lng`) straight off `users`. `findNearbyUsers`
/// (functions/src/index.ts) now does that scan server-side with Admin
/// SDK access to `users/{uid}/private/data`, applying Ghost Mode,
/// visibility radius, and the gender filter for real (all three were
/// silently bypassable client-side filters before this). Polling, not
/// realtime — see [kNearbyRefreshSeconds]'s own doc comment.
Stream<List<_RemoteCandidate>> _pollNearbyCandidates(
  GenderFilter genderFilter,
) async* {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'findNearbyUsers',
    options: callableOptions(),
  );
  while (true) {
    try {
      final genderWire = _genderFilterWireValue(genderFilter);
      final result = await callable.call<Map<String, dynamic>>({
        if (genderWire != null) 'genderFilter': genderWire,
      });
      final raw = (result.data['candidates'] as List).cast<dynamic>();
      yield raw
          .map(
            (e) =>
                _RemoteCandidate.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e, st) {
      logError('location_providers._pollNearbyCandidates', e, st);
      yield const [];
    }
    await Future.delayed(Duration(seconds: kNearbyRefreshSeconds));
  }
}

final _nearbyDistanceCandidatesProvider = StreamProvider.autoDispose
    .family<List<_RemoteCandidate>, GenderFilter>((ref, genderFilter) {
      return _pollNearbyCandidates(genderFilter);
    });

/// How often [_pollDiscoverCandidates] re-fetches while Ölkə/Dünya
/// mode is active — these two modes lost their realtime `.snapshots()`
/// listener when the VIP check moved server-side (see
/// `getDiscoverCandidates` in `functions/src/index.ts`; a Cloud
/// Function callable is one-shot, not a stream), so this polling loop
/// is what keeps them from going stale for as long as the sheet/map
/// stays on that mode.
const _discoverCandidatesPollInterval = Duration(seconds: 30);

/// Calls the `getDiscoverCandidates` Cloud Function on a timer — a
/// transient failure (network blip, cold start) logs and keeps polling
/// rather than killing the stream; a persistent `permission-denied`
/// (caller isn't actually Premium — the UI shouldn't let this happen,
/// but the function is the real gate) just yields empty lists forever,
/// same as "no results" would look before.
Stream<List<_RemoteCandidate>> _pollDiscoverCandidates({
  required String mode,
  String? country,
  required GenderFilter genderFilter,
}) async* {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'getDiscoverCandidates',
    options: callableOptions(),
  );
  while (true) {
    try {
      final genderWire = _genderFilterWireValue(genderFilter);
      final result = await callable.call<Map<String, dynamic>>({
        'mode': mode,
        if (country != null) 'country': country,
        if (genderWire != null) 'genderFilter': genderWire,
      });
      final raw = (result.data['candidates'] as List).cast<dynamic>();
      yield raw
          .map(
            (e) =>
                _RemoteCandidate.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e, st) {
      logError('location_providers._pollDiscoverCandidates', e, st);
      yield const [];
    }
    await Future.delayed(_discoverCandidatesPollInterval);
  }
}

/// Everyone online in [country] — backs "Ölkə üzrə". VIP-only: see
/// [_pollDiscoverCandidates]'s doc comment for why this is a poll
/// against a Cloud Function rather than a direct Firestore stream.
final _countryCandidatesProvider = StreamProvider.autoDispose
    .family<
      List<_RemoteCandidate>,
      ({String country, GenderFilter genderFilter})
    >((ref, params) {
      return _pollDiscoverCandidates(
        mode: 'country',
        country: params.country,
        genderFilter: params.genderFilter,
      );
    });

/// Everyone online worldwide — backs "Dünya üzrə". Same VIP-gated,
/// polled-Cloud-Function story as [_countryCandidatesProvider].
final _worldCandidatesProvider = StreamProvider.autoDispose
    .family<List<_RemoteCandidate>, GenderFilter>((ref, genderFilter) {
      return _pollDiscoverCandidates(mode: 'world', genderFilter: genderFilter);
    });

/// Live count of nearby users per radius option, recomputed from the
/// same server-filtered candidate list [nearbyUsersProvider]'s
/// distance-mode branch uses — no hardcoded numbers, no client-side
/// re-filtering (Ghost Mode/visibility radius/gender/blocks are already
/// applied by `findNearbyUsers`). Recalculates automatically whenever
/// the candidate set, position, or gender filter changes.
final radiusUserCountsProvider = Provider<Map<double, int>>((ref) {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final genderFilter = ref.watch(selectedGenderFilterProvider);
  final candidates =
      ref.watch(_nearbyDistanceCandidatesProvider(genderFilter)).valueOrNull ??
      const [];

  final counts = <double, int>{for (final km in kRadiusOptionsKm) km: 0};
  if (position == null) return counts;

  for (final candidate in candidates) {
    final distance = candidate.distanceMeters;
    if (distance == null) continue;
    for (final km in kRadiusOptionsKm) {
      if (distance <= km * 1000) counts[km] = counts[km]! + 1;
    }
  }

  return counts;
});

/// Live count backing the venue owner's live-audience counter
/// (`VenueProfileScreen`'s `_LiveAudienceCard`) — same 3 modes as
/// Discover's own [DiscoverRadiusSelection] ('distance'/'country'/
/// 'world'), just centered on a VENUE's fixed location/country instead
/// of the viewer's live position, and persisted per-venue rather than
/// transient per-session state. Backed by the `previewVenueAudience`
/// Cloud Function (owner-only, verifies `venue.ownerId == uid` itself)
/// since Düzəliş Prompt 4 moved `lat`/`lng`/`ghostModeEnabled` off the
/// public `users/{uid}` doc — this count can no longer be computed
/// client-side from a raw Firestore scan the way it used to be. Only
/// ever an aggregate number, no individual profiles are exposed by this
/// provider.
final venueAudienceCountProvider = FutureProvider.autoDispose
    .family<
      int,
      ({
        String venueId,
        String mode,
        double lat,
        double lng,
        double radiusKm,
        String? country,
      })
    >((ref, params) async {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'previewVenueAudience',
          options: callableOptions(),
        );
        final result = await callable.call<Map<String, dynamic>>({
          'venueId': params.venueId,
          'mode': params.mode,
          if (params.mode == 'country') 'country': params.country,
          if (params.mode == 'distance') 'lat': params.lat,
          if (params.mode == 'distance') 'lng': params.lng,
          if (params.mode == 'distance') 'radiusKm': params.radiusKm,
        });
        return (result.data['count'] as num?)?.toInt() ?? 0;
      } catch (e, st) {
        logError('location_providers.venueAudienceCountProvider', e, st);
        return 0;
      }
    });

final nearbyUsersProvider = Provider<List<NearbyUser>>((ref) {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  final genderFilter = ref.watch(selectedGenderFilterProvider);
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;

  if (position == null) return const [];

  final List<_RemoteCandidate> candidates;
  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      candidates =
          ref
              .watch(_nearbyDistanceCandidatesProvider(genderFilter))
              .valueOrNull ??
          const [];
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(
        profileControllerProvider.select((p) => p.country),
      );
      candidates = myCountry == null
          ? const []
          : ref
                    .watch(
                      _countryCandidatesProvider((
                        country: myCountry,
                        genderFilter: genderFilter,
                      )),
                    )
                    .valueOrNull ??
                const [];
    case DiscoverRadiusMode.world:
      candidates =
          ref.watch(_worldCandidatesProvider(genderFilter)).valueOrNull ??
          const [];
  }

  final result = <NearbyUser>[];

  for (final candidate in candidates) {
    // The server already excludes the caller/blocked pairs/Ghost Mode/
    // stale presence for every mode — this loop only builds display
    // objects and applies the mode-specific distance cutoff.
    if (candidate.uid == myUid) continue;
    if (candidate.lat == null || candidate.lng == null) continue;

    final distance =
        candidate.distanceMeters ??
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          candidate.lat!,
          candidate.lng!,
        );

    // Country/world modes show everyone the query already scoped —
    // no additional distance cutoff, unlike a real radius ring.
    if (selection.mode == DiscoverRadiusMode.distance &&
        distance > selection.km! * 1000)
      continue;

    result.add(
      NearbyUser(
        id: candidate.uid,
        // Empty when the user has no name on file — resolved to a localized
        // fallback ("İstifadəçi"/"User"/...) at display time, since this
        // provider has no BuildContext to translate with.
        name: '${candidate.firstName} ${candidate.lastName}'.trim(),
        username: candidate.username,
        lat: candidate.lat!,
        lng: candidate.lng!,
        bio: candidate.bio,
        photoUrl: candidate.photoUrl,
        online: candidate.online,
        age: candidate.age,
        lastSeen: candidate.lastSeen,
        distanceMeters: distance,
      ),
    );
  }

  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return result;
});
