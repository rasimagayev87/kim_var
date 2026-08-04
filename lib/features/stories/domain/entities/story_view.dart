/// One entry in a story's viewer list. Deliberately holds only the
/// viewer's id and when they viewed — name/photo are resolved at
/// display time via the existing `publicProfileProvider` rather than
/// duplicated here, so the viewer list never shows stale data if
/// someone updates their name/photo after viewing.
class StoryView {
  final String viewerId;
  final DateTime viewedAt;

  const StoryView({required this.viewerId, required this.viewedAt});
}
