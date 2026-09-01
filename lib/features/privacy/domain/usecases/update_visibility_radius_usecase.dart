import '../entities/privacy_settings.dart';
import '../repositories/privacy_settings_repository.dart';

/// Same Premium-gate note as [UpdateProfileVisibilityUseCase]: the
/// Ölkə/Dünya lock is a UI-level check, not re-validated here — all
/// distance (km) options are free for every user. [radiusKm] is only
/// written when [mode] is `distance` — Firestore
/// stores `null` (via `FieldValue`-free plain null) for `country`/`world`,
/// matching how [FirebasePrivacySettingsRepository] reads it back.
class UpdateVisibilityRadiusUseCase {
  const UpdateVisibilityRadiusUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({
    required String uid,
    required VisibilityRadiusMode mode,
    double? radiusKm,
  }) {
    return _repository.updateSettings(uid, {
      'visibilityRadiusMode': mode.name,
      'visibilityRadiusKm': mode == VisibilityRadiusMode.distance
          ? radiusKm
          : null,
    });
  }
}
