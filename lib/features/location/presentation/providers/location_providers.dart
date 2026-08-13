import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/utils/age_calculator.dart';
import '../../../../core/utils/presence_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../safety/presentation/providers/safety_providers.dart';
import '../../domain/location_failure.dart';
import '../../domain/nearby_user.dart';

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

  Future<Position> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(LocationFailure.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: _accuracy),
    );
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

  Future<void> _writePosition(Position position) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'lastSeen': FieldValue.serverTimestamp(),
      'online': true,
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}

/// Radius options matching the product spec (in kilometres): 100 m, 500 m
/// and 1 km are free; 5/10/30 km require Premium (see [isPremiumRadiusKm]).
const kRadiusOptionsKm = <double>[0.1, 0.5, 1, 5, 10, 30];

/// The 3 VIP-only distance options shown in the "Daha çox" panel
/// (Ölkə üzrə/Dünya üzrə live alongside these but aren't km values,
/// so they're not part of this list).
const kExtraRadiusOptionsKm = <double>[5, 10, 30];

/// The 3 free options shown in the always-visible row — everything
/// else (5/10 km here, plus 30 km/Ölkə/Dünya added in the "Daha çox"
/// panel) lives behind that trigger.
const kDefaultRadiusOptionsKm = <double>[0.1, 0.5, 1];

/// Radius options at or above this value require an active Premium
/// subscription. Kept as a single constant so the free/paid line only
/// needs to change in one place.
const kPremiumRadiusThresholdKm = 5.0;

bool isPremiumRadiusKm(double km) => km >= kPremiumRadiusThresholdKm;

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

/// Gender filter for the discover map/cards. Matches the free-text
/// `gender` values ('Kişi' / 'Qadın') already written to Firestore
/// by the profile edit screen.
enum GenderFilter { all, male, female }

final selectedGenderFilterProvider = StateProvider<GenderFilter>(
  (ref) => GenderFilter.all,
);

/// Real-time stream of other users' documents that have reported a
/// location within the last 15 minutes. Firestore doesn't support
/// native "within X km" geo-queries, so this fetches a bounded,
/// recently-active candidate set and [nearbyUsersProvider] below
/// filters it to the exact selected radius using real distance —
/// no simulated or fabricated data, all documents come from
/// Firestore. As the user base grows, this candidate query should
/// be upgraded to geohash-sharded queries to avoid scanning the
/// whole collection.
final _nearbyCandidatesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
  return FirebaseFirestore.instance
      .collection('users')
      .where('lastSeen', isGreaterThan: Timestamp.fromDate(cutoff))
      .limit(200)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((d) => {...d.data(), 'uid': d.id}).toList(),
      );
});

/// Everyone online in [country] — backs "Ölkə üzrə". Deliberately no
/// `lastSeen` recency cutoff (unlike [_nearbyCandidatesProvider]) —
/// country-wide is meant to surface anyone currently online, not just
/// the last 15 minutes. The `.limit` is defensive only (a populous
/// country could have many online users); real pagination/clustering
/// is a follow-up if this becomes a real bottleneck.
final _countryCandidatesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, country) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('country', isEqualTo: country)
          .where('online', isEqualTo: true)
          .limit(300)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((d) => {...d.data(), 'uid': d.id}).toList(),
          );
    });

/// Everyone online worldwide — backs "Dünya üzrə". Same defensive-cap
/// reasoning as [_countryCandidatesProvider], just a larger bound
/// since it's the broadest possible view.
final _worldCandidatesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('online', isEqualTo: true)
      .limit(500)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((d) => {...d.data(), 'uid': d.id}).toList(),
      );
});

/// True when either side of the pair has blocked the other — [myBlockedIds]
/// is the signed-in user's own block list, and [otherData] is the
/// candidate's raw user doc (whose own `blockedUsers` array tells us if
/// THEY blocked us, with no extra Firestore read needed).
bool _isBlockedPair(
  String myUid,
  Set<String> myBlockedIds,
  String otherUid,
  Map<String, dynamic> otherData,
) {
  if (myBlockedIds.contains(otherUid)) return true;
  final theirBlockedUsers =
      (otherData['blockedUsers'] as List?)?.cast<String>() ?? const [];
  return theirBlockedUsers.contains(myUid);
}

/// Ghost Mode's one and only job — see `PrivacySettings.ghostModeEnabled`'s
/// doc comment. A ghost-mode user is simply never a map/Discover
/// candidate; their profile page and media stay reachable through any
/// other route (chat, direct link, existing follow).
bool _isGhostMode(Map<String, dynamic> data) =>
    data['ghostModeEnabled'] as bool? ?? false;

/// Live count of nearby users per radius option, recomputed from the same
/// real Firestore candidate stream/position [nearbyUsersProvider] uses —
/// no hardcoded numbers. Also respects the current gender filter, so the
/// count next to each radius button matches what selecting it would
/// actually show. Recalculates automatically whenever the candidate set
/// or the device's position changes.
final radiusUserCountsProvider = Provider<Map<double, int>>((ref) {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final genderFilter = ref.watch(selectedGenderFilterProvider);
  final candidates =
      ref.watch(_nearbyCandidatesProvider).valueOrNull ?? const [];
  final myBlockedIds =
      ref.watch(blockedUserIdsProvider).valueOrNull ?? const {};
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;

  final counts = <double, int>{for (final km in kRadiusOptionsKm) km: 0};
  if (position == null) return counts;

  for (final data in candidates) {
    final uid = data['uid'] as String?;
    if (uid == null || uid == myUid) continue;
    if (myUid != null && _isBlockedPair(myUid, myBlockedIds, uid, data))
      continue;
    if (_isGhostMode(data)) continue;

    // Keeps this count in sync with [nearbyUsersProvider]'s own
    // filter below — otherwise a radius button could say "12 nearby"
    // while only showing 5 pins, because most of the 12 are stale
    // `online: true` writes rather than someone actually online now.
    final candidateOnline = data['online'] as bool? ?? false;
    final candidateLastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
    if (!isRecentlyOnline(online: candidateOnline, lastSeen: candidateLastSeen)) continue;

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;

    final gender = data['gender'] as String?;
    if (genderFilter == GenderFilter.male && gender != 'Kişi') continue;
    if (genderFilter == GenderFilter.female && gender != 'Qadın') continue;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lat,
      lng,
    );

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
/// transient per-session state. Ghost-mode users are excluded from
/// every mode, same privacy rule as every other nearby-type computation
/// in this file — only ever an aggregate number, no individual profiles
/// are exposed by this provider.
final venueAudienceCountProvider =
    Provider.family<
      int,
      ({String mode, double lat, double lng, double radiusKm, String? country})
    >((ref, params) {
      switch (params.mode) {
        case 'country':
          final country = params.country;
          if (country == null) return 0;
          final candidates =
              ref.watch(_countryCandidatesProvider(country)).valueOrNull ??
              const [];
          return candidates.where((d) => !_isGhostMode(d)).length;

        case 'world':
          final candidates =
              ref.watch(_worldCandidatesProvider).valueOrNull ?? const [];
          return candidates.where((d) => !_isGhostMode(d)).length;

        case 'distance':
        default:
          final candidates =
              ref.watch(_nearbyCandidatesProvider).valueOrNull ?? const [];
          var count = 0;
          for (final data in candidates) {
            if (_isGhostMode(data)) continue;

            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) continue;

            final distance = Geolocator.distanceBetween(
              params.lat,
              params.lng,
              lat,
              lng,
            );
            if (distance <= params.radiusKm * 1000) count++;
          }
          return count;
      }
    });

final nearbyUsersProvider = Provider<List<NearbyUser>>((ref) {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final selection = ref.watch(selectedDiscoverModeProvider);
  final genderFilter = ref.watch(selectedGenderFilterProvider);
  final myBlockedIds =
      ref.watch(blockedUserIdsProvider).valueOrNull ?? const {};
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;

  if (position == null) return const [];

  final List<Map<String, dynamic>> candidates;
  switch (selection.mode) {
    case DiscoverRadiusMode.distance:
      candidates = ref.watch(_nearbyCandidatesProvider).valueOrNull ?? const [];
    case DiscoverRadiusMode.country:
      final myCountry = ref.watch(
        profileControllerProvider.select((p) => p.country),
      );
      candidates = myCountry == null
          ? const []
          : ref.watch(_countryCandidatesProvider(myCountry)).valueOrNull ??
                const [];
    case DiscoverRadiusMode.world:
      candidates = ref.watch(_worldCandidatesProvider).valueOrNull ?? const [];
  }

  final result = <NearbyUser>[];

  for (final data in candidates) {
    final uid = data['uid'] as String?;
    if (uid == null || uid == myUid) continue;
    if (myUid != null && _isBlockedPair(myUid, myBlockedIds, uid, data))
      continue;
    if (_isGhostMode(data)) continue;

    // The map only ever shows who's online RIGHT NOW — [_nearbyCandidatesProvider]'s
    // own 15-minute lastSeen window (and the country/world modes' raw
    // `online == true` query, which has no staleness check at all) both
    // exist purely to bound how much of `users` gets scanned/streamed,
    // not to decide who's actually still online. This is that decision
    // — the same self-healing check `discover_tab.dart` uses for the
    // green dot, applied here to the pin's existence too: signing out
    // (writes `online: false` immediately) or a stale write past
    // `kOnlineStalenessThreshold` both make someone disappear from the
    // map, not just lose their dot.
    final candidateOnline = data['online'] as bool? ?? false;
    final candidateLastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
    if (!isRecentlyOnline(online: candidateOnline, lastSeen: candidateLastSeen)) continue;

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lat,
      lng,
    );
    // Country/world modes show everyone the query already scoped —
    // no additional distance cutoff, unlike a real radius ring.
    if (selection.mode == DiscoverRadiusMode.distance &&
        distance > selection.km! * 1000)
      continue;

    final gender = data['gender'] as String?;
    if (genderFilter == GenderFilter.male && gender != 'Kişi') continue;
    if (genderFilter == GenderFilter.female && gender != 'Qadın') continue;

    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final birthDate = (data['birthDate'] as Timestamp?)?.toDate();

    result.add(
      NearbyUser(
        id: uid,
        // Empty when the user has no name on file — resolved to a localized
        // fallback ("İstifadəçi"/"User"/...) at display time, since this
        // provider has no BuildContext to translate with.
        name: fullName,
        lat: lat,
        lng: lng,
        bio: data['bio'] as String? ?? '',
        photoUrl: data['photoUrl'] as String?,
        online: data['online'] as bool? ?? false,
        age: birthDate == null ? null : calculateAge(birthDate),
        gender: gender,
        starCount: (data['starCount'] as num?)?.toInt() ?? 0,
        heartCount: (data['heartCount'] as num?)?.toInt() ?? 0,
        dislikeCount: (data['dislikeCount'] as num?)?.toInt() ?? 0,
        lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
        distanceMeters: distance,
      ),
    );
  }

  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return result;
});
