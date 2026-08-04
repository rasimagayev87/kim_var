import '../../../../../core/utils/distance_unit.dart';

enum AppMapType { standard, satellite, hybrid }

enum GpsAccuracyLevel { high, standard }

class MapLocationSettings {
  final AppMapType mapType;
  final DistanceUnit distanceUnit;
  final GpsAccuracyLevel gpsAccuracy;

  /// Whether "Always Allow" location permission has been granted.
  /// Turning this on lets live position updates keep reaching
  /// Firestore while the app is backgrounded (not force-quit) — it
  /// does not run a killed-app background service.
  final bool backgroundLocationEnabled;

  const MapLocationSettings({
    this.mapType = AppMapType.standard,
    this.distanceUnit = DistanceUnit.km,
    this.gpsAccuracy = GpsAccuracyLevel.high,
    this.backgroundLocationEnabled = false,
  });
}
