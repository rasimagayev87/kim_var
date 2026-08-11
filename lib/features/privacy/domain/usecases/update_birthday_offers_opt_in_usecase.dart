import '../repositories/privacy_settings_repository.dart';

/// No premium gate, unlike `UpdateGhostModeUseCase` — this is a plain
/// opt-in, free for every user.
class UpdateBirthdayOffersOptInUseCase {
  const UpdateBirthdayOffersOptInUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required bool enabled}) {
    return _repository.updateSettings(uid, {'birthdayOffersOptIn': enabled});
  }
}
