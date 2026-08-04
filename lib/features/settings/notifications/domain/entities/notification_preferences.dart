/// Stored as a nested `notificationPreferences` map on `users/{uid}`
/// (not a new collection) — the existing owner-update rule on that
/// doc already covers it, no rules change needed.
class NotificationPreferences {
  final bool messages;
  final bool followers;
  final bool newUsers;
  final bool likes;
  final bool comments;
  final bool venueOffers;
  final bool venueUpdates;
  final bool security;
  final bool systemNotifications;
  final bool marketing;

  /// Master switch — off overrides every category above (they all
  /// stay unsubscribed on-device regardless of their own flag).
  final bool pushEnabled;

  /// No transactional email service is configured yet (same gap noted
  /// for account email changes) — this is a real, stored preference,
  /// but nothing currently sends an email because of it.
  final bool emailEnabled;

  const NotificationPreferences({
    this.messages = true,
    this.followers = true,
    this.newUsers = true,
    this.likes = true,
    this.comments = true,
    this.venueOffers = true,
    this.venueUpdates = true,
    this.security = true,
    this.systemNotifications = true,
    this.marketing = false,
    this.pushEnabled = true,
    this.emailEnabled = false,
  });

  bool categoryValue(String key) {
    switch (key) {
      case 'messages':
        return messages;
      case 'followers':
        return followers;
      case 'newUsers':
        return newUsers;
      case 'likes':
        return likes;
      case 'comments':
        return comments;
      case 'venueOffers':
        return venueOffers;
      case 'venueUpdates':
        return venueUpdates;
      case 'security':
        return security;
      case 'systemNotifications':
        return systemNotifications;
      case 'marketing':
        return marketing;
      default:
        return false;
    }
  }
}
