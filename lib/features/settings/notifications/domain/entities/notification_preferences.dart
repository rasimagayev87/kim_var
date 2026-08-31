/// Stored as a nested `notificationPreferences` map on
/// `users/{uid}/private/data` — owner-writable by design (these are the
/// user's own choices, so the field is deliberately NOT in
/// `serverOnlyFields()`), and readable/writable by nobody else.
///
/// Every key here is gated server-side in `notifyUser`
/// (functions/src/index.ts). Two categories are deliberately absent:
/// `security` and `account` are UNGATED — see
/// `functions/src/notification-categories.ts` for which notification
/// types they cover and why a failed charge or a "your table is ready"
/// must not be silenceable. They are not fields here because there is
/// no switch to store.
///
/// `newUsers` and `emailEnabled` were removed on 2026-08-31: no server
/// code read either. `newUsers` gated nothing at all, and
/// `emailEnabled` described an email service this project has never
/// had. A stored flag nothing consults is a switch that lies.
class NotificationPreferences {
  final bool messages;
  final bool followers;
  final bool likes;
  final bool comments;
  final bool venueOffers;
  final bool venueUpdates;
  final bool systemNotifications;
  final bool marketing;

  /// Master switch. Suppresses the PUSH for every notification —
  /// including the ungated `security`/`account` ones — but not the
  /// in-app feed entry, which `notifyUser` writes before consulting
  /// this. So a user who turns this off still finds "ödənişiniz
  /// uğursuz oldu" waiting in Bildirişlər; they have chosen not to be
  /// interrupted, not to be uninformed. Matches what the OS-level
  /// permission would do anyway, which the app cannot override.
  final bool pushEnabled;

  const NotificationPreferences({
    this.messages = true,
    this.followers = true,
    this.likes = true,
    this.comments = true,
    this.venueOffers = true,
    this.venueUpdates = true,
    this.systemNotifications = true,
    this.marketing = false,
    this.pushEnabled = true,
  });

  bool categoryValue(String key) {
    switch (key) {
      case 'messages':
        return messages;
      case 'followers':
        return followers;
      case 'likes':
        return likes;
      case 'comments':
        return comments;
      case 'venueOffers':
        return venueOffers;
      case 'venueUpdates':
        return venueUpdates;
      case 'systemNotifications':
        return systemNotifications;
      case 'marketing':
        return marketing;
      default:
        return false;
    }
  }
}
