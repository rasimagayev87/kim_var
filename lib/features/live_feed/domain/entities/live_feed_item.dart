/// Which existing module a [LiveFeedItem] was derived from — purely a
/// presentation/grouping label, never written to Firestore.
enum LiveFeedType { audience, event, offer, seatAvailable, birthday }

/// One row in the "Canlı" tab — a normalized, read-only projection of
/// a document that already lives in `venues`, `offers`, `venueEvents`,
/// or a venue's `activeCheckins` subcollection. Nothing about this
/// class is ever persisted; it exists purely to give
/// `LiveFeedService`'s five very different source queries one common
/// shape the UI can render without knowing which collection a card
/// came from.
class LiveFeedItem {
  final String id;
  final LiveFeedType type;

  /// The venue this item is about or belongs to — always set, even for
  /// [LiveFeedType.event]/[LiveFeedType.offer]/[LiveFeedType.birthday]
  /// (where it's the hosting/offering venue, not the tap target).
  final String venueId;

  /// Where tapping this card navigates — the venue itself for
  /// [LiveFeedType.audience]/[LiveFeedType.seatAvailable], or the
  /// underlying offer/event id for the other three. [targetType]
  /// mirrors the same 'venue'/'offer'/'event' vocabulary
  /// `notification_navigation.dart` already uses for its own
  /// `targetType` switch, so a future "open this from a Canlı card"
  /// deep link could reuse that exact dispatch if ever needed —
  /// though today's cards navigate directly, not through it.
  final String targetId;
  final String targetType;

  final String title;
  final String subtitle;
  final double distanceMeters;

  /// The hosting venue's own profile photo — `null` if it hasn't set
  /// one, or for [LiveFeedType.audience] (a system announcement, not
  /// venue content; never populated for that type on purpose). The
  /// card falls back to the generic per-type icon whenever this is
  /// null, exactly like every other `venue.photoUrl` call site.
  final String? photoUrl;

  /// What "freshness" means depends on [type] — an event's own
  /// `startAt`, an offer's `createdAt`, a seat count's `seatsUpdatedAt`,
  /// or simply "now" for a live audience/birthday-match read. See
  /// `LiveFeedService`'s per-type doc comments for the exact source.
  final DateTime timestamp;

  const LiveFeedItem({
    required this.id,
    required this.type,
    required this.venueId,
    required this.targetId,
    required this.targetType,
    required this.title,
    required this.subtitle,
    required this.distanceMeters,
    required this.timestamp,
    this.photoUrl,
  });
}
