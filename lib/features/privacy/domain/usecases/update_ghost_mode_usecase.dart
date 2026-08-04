import '../repositories/privacy_settings_repository.dart';

/// The Premium gate itself is a UI-level check (same pattern as the
/// locked 5/10km Discover radius options — see
/// `isPremiumRadiusKm`/`showPremiumUpsellSheet`), not re-checked here:
/// by the time this usecase runs, the UI has already decided the user
/// is allowed to set this value.
class UpdateGhostModeUseCase {
  const UpdateGhostModeUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required bool enabled}) {
    return _repository.updateSettings(uid, {'ghostModeEnabled': enabled});
  }
}
