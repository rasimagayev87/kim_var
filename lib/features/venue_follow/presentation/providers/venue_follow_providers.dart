import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_venue_follow_repository.dart';
import '../../domain/repositories/venue_follow_repository.dart';

final venueFollowRepositoryProvider = Provider<VenueFollowRepository>((ref) => FirebaseVenueFollowRepository());

/// Whether the signed-in user follows [venueId] — drives the "İzlə"
/// button state on `VenueProfileScreen`.
final isVenueFollowedByMeProvider = StreamProvider.autoDispose.family<bool, String>((ref, venueId) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return ref.watch(venueFollowRepositoryProvider).watchIsFollowing(venueId: venueId, uid: uid);
});

/// Every venue id the signed-in user follows — what the "Canlı" feed's
/// radius-bypass query reads.
final myFollowedVenueIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(venueFollowRepositoryProvider).watchFollowedVenueIds(uid);
});

class VenueFollowController {
  VenueFollowController(this._ref);

  final Ref _ref;

  /// Returns true on success (logged internally on failure) — matches
  /// every other toggle-style controller in this app.
  Future<bool> toggle({required String venueId, required bool isCurrentlyFollowing}) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      if (isCurrentlyFollowing) {
        await _ref.read(venueFollowRepositoryProvider).unfollow(venueId: venueId, uid: uid);
      } else {
        await _ref.read(venueFollowRepositoryProvider).follow(venueId: venueId, uid: uid);
      }
      return true;
    } catch (e, st) {
      logError('venue_follow_providers.toggle', e, st);
      return false;
    }
  }
}

final venueFollowControllerProvider = Provider<VenueFollowController>((ref) => VenueFollowController(ref));
