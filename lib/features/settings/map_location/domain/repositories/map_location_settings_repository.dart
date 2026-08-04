import '../entities/map_location_settings.dart';

abstract class MapLocationSettingsRepository {
  Stream<MapLocationSettings> watchSettings(String uid);

  Future<void> updateSettings(String uid, Map<String, dynamic> changes);
}
