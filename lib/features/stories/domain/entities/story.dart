enum StoryMediaType { image, video }

/// A single 24h-expiring story post. Expiry is enforced client-side
/// (queries filter `expiresAt > now`, see FirebaseStoryRepository) —
/// no Cloud Function is required for the feature to work correctly;
/// one could be added later purely to delete long-expired docs/files
/// so they don't accumulate, but that's a storage-hygiene concern, not
/// a correctness one.
///
/// Has no visibility field of its own — who can see it is entirely a
/// function of [creatorId]'s own `AccountPrivacy` at VIEW time (see
/// "Hesab gizliliyi" / `activeStoriesForUserProvider`), not a per-post
/// choice frozen in at creation. A pre-"Hesab gizliliyi" story doc may
/// still carry an old `visibility` field in Firestore — nothing reads
/// it anymore, and it ages out on its own within 24h of that doc's
/// creation regardless.
class Story {
  final String id;
  final String creatorId;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;

  const Story({
    required this.id,
    required this.creatorId,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
