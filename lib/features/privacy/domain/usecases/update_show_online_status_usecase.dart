import '../repositories/privacy_settings_repository.dart';

class UpdateShowOnlineStatusUseCase {
  const UpdateShowOnlineStatusUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required bool show}) {
    return _repository.updateSettings(uid, {'showOnlineStatus': show});
  }
}
