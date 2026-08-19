import '../repositories/privacy_settings_repository.dart';

/// The Premium gate itself is a UI-level check (same pattern as
/// [UpdateGhostModeUseCase]), not re-checked here.
class UpdateIncognitoBrowsingUseCase {
  const UpdateIncognitoBrowsingUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required bool enabled}) {
    return _repository.updateSettings(uid, {'incognitoBrowsingEnabled': enabled});
  }
}
