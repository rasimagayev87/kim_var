import '../entities/waitlist_entry.dart';

abstract class WaitlistRepository {
  /// Joins [venueId]'s waitlist as [userId] — starts `waiting` with no
  /// `queuePosition` (server-computed, see `WaitlistEntry`'s doc
  /// comment). Returns the new entry's id.
  Future<String> joinWaitlist({
    required String venueId,
    required String userId,
    required int partySize,
    required String phoneNumber,
    String? note,
  });

  /// The signed-in user's own still-active (waiting or called) entry
  /// for this venue, if any — null once it's seated/cancelled/no-show,
  /// or if they never joined. Backs the live "sıra nömrəniz" display.
  Stream<WaitlistEntry?> watchMyEntry({required String venueId, required String userId});

  /// Owner view — every `waiting` OR `called` entry for this venue,
  /// `joinedAt` ascending (oldest first, i.e. queue order). Backs the
  /// "Növbə" management list, which needs both: a called entry still
  /// needs its Gəldi/Gəlmədi buttons until it resolves.
  Stream<List<WaitlistEntry>> watchWaitingList(String venueId);

  /// The user cancels their own entry — only valid while `waiting`.
  Future<void> cancelEntry({required String venueId, required String entryId});

  /// Owner calls this entry forward — `status: called`, `calledAt` set.
  /// The `waitlistCalled` push/in-app notification is sent server-side
  /// by `onWaitlistEntryWritten` reacting to this exact transition, not
  /// from here.
  Future<void> callEntry({required String venueId, required String entryId});

  Future<void> markSeated({required String venueId, required String entryId});

  Future<void> markNoShow({required String venueId, required String entryId});

  /// Owner's "Sil" — removes a still-waiting entry (`status: cancelled`).
  Future<void> removeEntry({required String venueId, required String entryId});

  /// Owner's "Növbəni aktivləşdir/söndür" toggle — see `Venue.waitlistEnabled`.
  Future<void> setWaitlistEnabled({required String venueId, required bool enabled});

  /// One-shot existence check — whether this venue has EVER had any
  /// waitlist entry, any status. Same reasoning as `VenueEventRepository
  /// .hasAnyEvent`: keeps the "Növbə" menu entry reachable for a venue
  /// whose category is no longer waitlist-eligible but still has
  /// entries to resolve (see `waitlistCategoryConfigProvider`).
  Future<bool> hasAnyEntry(String venueId);
}
