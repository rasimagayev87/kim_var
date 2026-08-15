import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../venues/domain/entities/venue.dart' show TimestampConverter, NullableTimestampConverter;

part 'waitlist_entry.freezed.dart';
part 'waitlist_entry.g.dart';

/// `venues/{venueId}/waitlist/{entryId}.status` — [waiting] is the only
/// state [queuePosition] is meaningful for; every other state is a
/// terminal outcome the owner (or the user, for [cancelled]) moved the
/// entry to.
enum WaitlistEntryStatus { waiting, called, seated, cancelled, noShow }

class WaitlistEntryStatusConverter implements JsonConverter<WaitlistEntryStatus, String?> {
  const WaitlistEntryStatusConverter();

  @override
  WaitlistEntryStatus fromJson(String? json) =>
      WaitlistEntryStatus.values.firstWhere((s) => s.name == json, orElse: () => WaitlistEntryStatus.waiting);

  @override
  String toJson(WaitlistEntryStatus status) => status.name;
}

/// One user's place in a venue's walk-in waitlist. [queuePosition] is
/// never client-written — see `maintainWaitlistQueuePositions` (Cloud
/// Function, functions/src/index.ts), which recomputes it for every
/// `waiting` entry under a venue on every create/status change, so two
/// people joining at the same instant can't race into the same number.
@freezed
class WaitlistEntry with _$WaitlistEntry {
  const WaitlistEntry._();

  const factory WaitlistEntry({
    required String id,
    required String venueId,
    required String userId,
    required int partySize,

    /// E.164 (e.g. `+994501234567`) — collected so the venue can call
    /// about the queue; never shown to anyone but the venue's own
    /// owner and the entry's own creator (see `firestore.rules`, same
    /// read gate every other field on this doc already has).
    required String phoneNumber,

    /// Free-text, optional — absent (not empty string) when not
    /// provided, same "omit rather than store blank" convention as
    /// `Venue.country`/`VenueSocialLinks` fields elsewhere.
    String? note,
    @WaitlistEntryStatusConverter() @Default(WaitlistEntryStatus.waiting) WaitlistEntryStatus status,
    @TimestampConverter() required DateTime joinedAt,
    @NullableTimestampConverter() DateTime? calledAt,

    /// Only ever set while [status] is [WaitlistEntryStatus.waiting] —
    /// null for every other status (a called/seated/cancelled/no-show
    /// entry isn't "in line" anymore).
    int? queuePosition,
  }) = _WaitlistEntry;

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) => _$WaitlistEntryFromJson(json);

  factory WaitlistEntry.fromFirestore(String id, String venueId, Map<String, dynamic> data) {
    return WaitlistEntry.fromJson({...data, 'id': id, 'venueId': venueId});
  }
}
