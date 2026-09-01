import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/utils/distance_unit.dart';
import '../../../../../core/utils/private_data_ref.dart';
import '../../domain/entities/map_location_settings.dart';
import '../../domain/repositories/map_location_settings_repository.dart';

/// `mapLocationSettings` lives on `users/{uid}/private/data` (Düzəliş
/// Prompt 4) — see `privateDataRef`'s own doc comment.
class FirebaseMapLocationSettingsRepository
    implements MapLocationSettingsRepository {
  FirebaseMapLocationSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return privateDataRef(uid, firestore: _firestore);
  }

  @override
  Stream<MapLocationSettings> watchSettings(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final map = snap.data()?['mapLocationSettings'] as Map<String, dynamic>?;
      if (map == null) return const MapLocationSettings();
      return MapLocationSettings(
        mapType: AppMapType.values.firstWhere(
          (v) => v.name == map['mapType'],
          orElse: () => AppMapType.standard,
        ),
        distanceUnit: DistanceUnit.values.firstWhere(
          (v) => v.name == map['distanceUnit'],
          orElse: () => DistanceUnit.km,
        ),
        gpsAccuracy: GpsAccuracyLevel.values.firstWhere(
          (v) => v.name == map['gpsAccuracy'],
          orElse: () => GpsAccuracyLevel.high,
        ),
        backgroundLocationEnabled:
            map['backgroundLocationEnabled'] as bool? ?? false,
      );
    });
  }

  @override
  Future<void> updateSettings(String uid, Map<String, dynamic> changes) {
    final data = <String, dynamic>{
      for (final entry in changes.entries)
        'mapLocationSettings.${entry.key}': entry.value,
    };
    // Must be update(), not set(merge:true) — only update() interprets a
    // dotted key like 'mapLocationSettings.mapType' as a nested field
    // path. set(merge:true) writes it as one literal top-level field
    // whose name contains a dot, so the nested map watchSettings reads
    // from never actually gets created — every change silently no-ops
    // and the read falls back to defaults forever (see the identical
    // bug/fix in FirebaseNotificationPreferencesRepository.updatePreferences).
    return _userDoc(uid).update(data);
  }
}
