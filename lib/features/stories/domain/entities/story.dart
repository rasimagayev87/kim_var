enum StoryMediaType { image, video }

enum StoryVisibility { followers, everyone }

/// A single 24h-expiring story post. Expiry is enforced client-side
/// (queries filter `expiresAt > now`, see FirebaseStoryRepository) —
/// no Cloud Function is required for the feature to work correctly;
/// one could be added later purely to delete long-expired docs/files
/// so they don't accumulate, but that's a storage-hygiene concern, not
/// a correctness one.
class Story {
  final String id;
  final String creatorId;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final StoryVisibility visibility;
  final DateTime createdAt;
  final DateTime expiresAt;

  const Story({
    required this.id,
    required this.creatorId,
    required this.mediaUrl,
    required this.mediaType,
    required this.visibility,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
