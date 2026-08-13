import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_waitlist_repository.dart';
import '../../domain/entities/waitlist_entry.dart';
import '../../domain/repositories/waitlist_repository.dart';

final waitlistRepositoryProvider = Provider<WaitlistRepository>((ref) => FirebaseWaitlistRepository());

/// The signed-in user's own active entry in [venueId]'s waitlist, if
/// any — powers the live "sıra nömrəniz" display on `VenueProfileScreen`.
final myWaitlistEntryProvider = StreamProvider.autoDispose.family<WaitlistEntry?, String>((ref, venueId) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(waitlistRepositoryProvider).watchMyEntry(venueId: venueId, userId: uid);
});

/// Owner-only "Növbə" list — every `waiting` entry, queue order.
final venueWaitingListProvider = StreamProvider.autoDispose.family<List<WaitlistEntry>, String>((ref, venueId) {
  return ref.watch(waitlistRepositoryProvider).watchWaitingList(venueId);
});

class WaitlistController {
  WaitlistController(this._ref);

  final Ref _ref;

  Future<bool> join({required String venueId, required int partySize}) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _ref.read(waitlistRepositoryProvider).joinWaitlist(venueId: venueId, userId: uid, partySize: partySize);
      return true;
    } catch (e, st) {
      logError('waitlist_providers.join', e, st);
      return false;
    }
  }

  Future<bool> cancel({required String venueId, required String entryId}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).cancelEntry(venueId: venueId, entryId: entryId));

  Future<bool> call({required String venueId, required String entryId}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).callEntry(venueId: venueId, entryId: entryId));

  Future<bool> markSeated({required String venueId, required String entryId}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).markSeated(venueId: venueId, entryId: entryId));

  Future<bool> markNoShow({required String venueId, required String entryId}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).markNoShow(venueId: venueId, entryId: entryId));

  Future<bool> remove({required String venueId, required String entryId}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).removeEntry(venueId: venueId, entryId: entryId));

  Future<bool> setEnabled({required String venueId, required bool enabled}) =>
      _run(() => _ref.read(waitlistRepositoryProvider).setWaitlistEnabled(venueId: venueId, enabled: enabled));

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e, st) {
      logError('waitlist_providers', e, st);
      return false;
    }
  }
}

final waitlistControllerProvider = Provider<WaitlistController>((ref) => WaitlistController(ref));
