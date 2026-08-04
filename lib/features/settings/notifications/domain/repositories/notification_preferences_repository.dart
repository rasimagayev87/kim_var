import '../entities/notification_preferences.dart';

abstract class NotificationPreferencesRepository {
  Stream<NotificationPreferences> watchPreferences(String uid);

  Future<void> updatePreferences(String uid, Map<String, bool> changes);

  Future<void> subscribeToTopic(String topic);

  Future<void> unsubscribeFromTopic(String topic);
}
