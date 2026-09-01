import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/distance_unit.dart';
import '../../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../../app_config/presentation/utils/read_only_guard.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../location/presentation/providers/location_providers.dart';
import '../../data/repositories/firebase_map_location_settings_repository.dart';
import '../../domain/entities/map_location_settings.dart';
import '../../domain/repositories/map_location_settings_repository.dart';

gmaps.MapType toGoogleMapType(AppMapType type) {
  switch (type) {
    case AppMapType.standard:
      return gmaps.MapType.normal;
    case AppMapType.satellite:
      return gmaps.MapType.satellite;
    case AppMapType.hybrid:
      return gmaps.MapType.hybrid;
  }
}

LocationAccuracy toLocationAccuracy(GpsAccuracyLevel level) {
  return level == GpsAccuracyLevel.high
      ? LocationAccuracy.high
      : LocationAccuracy.medium;
}

final mapLocationSettingsRepositoryProvider =
    Provider<MapLocationSettingsRepository>((ref) {
      return FirebaseMapLocationSettingsRepository();
    });

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final mapLocationSettingsProvider =
    StreamProvider.autoDispose<MapLocationSettings>((ref) {
      // Forces a rebuild on sign-out/sign-in — without it, a quick account
      // switch can resurrect this provider still bound to the previous
      // uid before autoDispose's own teardown-triggered disposal fires,
      // silently showing the PREVIOUS account's map/location settings
      // under the new session. Same fix pattern as
      // `chatListControllerProvider`/`_premiumStatusProvider`.
      ref.watch(authStateProvider);
      final uid = _currentUid();
      if (uid == null) return Stream.value(const MapLocationSettings());
      return ref
          .watch(mapLocationSettingsRepositoryProvider)
          .watchSettings(uid);
    });

/// Bacground-permission-request outcome, so the screen can show the
/// right message without re-deriving Geolocator semantics itself.
enum BackgroundLocationResult { granted, deniedNeedsSettings, failed }

class MapLocationSettingsController {
  MapLocationSettingsController(this._ref);

  final Ref _ref;

  Future<bool> updateMapType(AppMapType type) {
    return _run({'mapType': type.name});
  }

  Future<bool> updateDistanceUnit(DistanceUnit unit) {
    return _run({'distanceUnit': unit.name});
  }

  Future<bool> updateGpsAccuracy(GpsAccuracyLevel level) async {
    final ok = await _run({'gpsAccuracy': level.name});
    if (ok) {
      _ref
          .read(locationControllerProvider.notifier)
          .applyAccuracy(toLocationAccuracy(level));
    }
    return ok;
  }

  /// Requests OS "Always Allow" permission. Only persists the
  /// preference as enabled once that permission is actually granted —
  /// this toggle never lies about what the OS allowed.
  Future<BackgroundLocationResult> enableBackgroundLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always) {
        final ok = await _run({'backgroundLocationEnabled': true});
        return ok
            ? BackgroundLocationResult.granted
            : BackgroundLocationResult.failed;
      }
      return BackgroundLocationResult.deniedNeedsSettings;
    } catch (e, st) {
      logError(
        'map_location_providers.MapLocationSettingsController.enableBackgroundLocation',
        e,
        st,
      );
      return BackgroundLocationResult.failed;
    }
  }

  Future<bool> disableBackgroundLocation() {
    return _run({'backgroundLocationEnabled': false});
  }

  Future<bool> _run(Map<String, dynamic> changes) async {
    final uid = _currentUid();
    if (uid == null) return false;
    if (!ensureWritableOrWarn(_ref.read(appConfigProvider))) return false;
    try {
      await _ref
          .read(mapLocationSettingsRepositoryProvider)
          .updateSettings(uid, changes);
      return true;
    } catch (e, st) {
      logError('map_location_providers.MapLocationSettingsController', e, st);
      return false;
    }
  }
}

final mapLocationSettingsControllerProvider =
    Provider<MapLocationSettingsController>((ref) {
      return MapLocationSettingsController(ref);
    });
