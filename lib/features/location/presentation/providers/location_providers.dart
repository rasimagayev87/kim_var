import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/location_failure.dart';
import '../../domain/nearby_user.dart';

final locationControllerProvider =
    StateNotifierProvider<LocationController, AsyncValue<Position>>((ref) {
  return LocationController()..refresh();
});

class LocationController extends StateNotifier<AsyncValue<Position>> {
  LocationController({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        super(const AsyncValue.loading());

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  StreamSubscription<Position>? _liveSubscription;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_getPosition);
    final position = state.valueOrNull;
    if (position != null) {
      await _writePosition(position);
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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Streams position updates in the background so the user's
  /// coordinates in Firestore (and therefore how they appear to
  /// others on the map) stay live while the app is open.
  void _startLiveUpdates() {
    _liveSubscription?.cancel();
    _liveSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
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
    await _firestore.collection('users').doc(uid).set(
      {
        'lat': position.latitude,
        'lng': position.longitude,
        'lastSeen': FieldValue.serverTimestamp(),
        'online': true,
      },
      SetOptions(merge: true),
    );
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}

/// Radius options matching the product spec (in kilometres).
const kRadiusOptionsKm = <double>[1, 5, 10, 25, 50];

final selectedRadiusKmProvider = StateProvider<double>((ref) => 1.0);

/// Gender filter for the discover map/cards. Matches the free-text
/// `gender` values ('Kişi' / 'Qadın') already written to Firestore
/// by the profile edit screen.
enum GenderFilter { all, male, female }

final selectedGenderFilterProvider = StateProvider<GenderFilter>((ref) => GenderFilter.all);

/// Real-time stream of other users' documents that have reported a
/// location within the last 15 minutes. Firestore doesn't support
/// native "within X km" geo-queries, so this fetches a bounded,
/// recently-active candidate set and [nearbyUsersProvider] below
/// filters it to the exact selected radius using real distance —
/// no simulated or fabricated data, all documents come from
/// Firestore. As the user base grows, this candidate query should
/// be upgraded to geohash-sharded queries to avoid scanning the
/// whole collection.
final _nearbyCandidatesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
  return FirebaseFirestore.instance
      .collection('users')
      .where('lastSeen', isGreaterThan: Timestamp.fromDate(cutoff))
      .limit(200)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
});

final nearbyUsersProvider = Provider<List<NearbyUser>>((ref) {
  final position = ref.watch(locationControllerProvider).valueOrNull;
  final radiusKm = ref.watch(selectedRadiusKmProvider);
  final genderFilter = ref.watch(selectedGenderFilterProvider);
  final candidates = ref.watch(_nearbyCandidatesProvider).valueOrNull ?? const [];
  final myUid = fb.FirebaseAuth.instance.currentUser?.uid;

  if (position == null) return const [];

  final result = <NearbyUser>[];

  for (final data in candidates) {
    final uid = data['uid'] as String?;
    if (uid == null || uid == myUid) continue;

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lat,
      lng,
    );
    if (distance > radiusKm * 1000) continue;

    final gender = data['gender'] as String?;
    if (genderFilter == GenderFilter.male && gender != 'Kişi') continue;
    if (genderFilter == GenderFilter.female && gender != 'Qadın') continue;

    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final interests = (data['interests'] as List?)?.cast<String>() ?? const [];

    result.add(NearbyUser(
      id: uid,
      name: fullName.isEmpty ? 'İstifadəçi' : fullName,
      lat: lat,
      lng: lng,
      mainInterest: interests.isNotEmpty ? interests.first : '',
      photoUrl: data['photoUrl'] as String?,
      online: data['online'] as bool? ?? false,
      age: data['age'] as int?,
      gender: gender,
      distanceMeters: distance,
    ));
  }

  result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return result;
});
