import '../entities/privacy_settings.dart';
import '../repositories/privacy_settings_repository.dart';

class UpdateWhoCanMessageMeUseCase {
  const UpdateWhoCanMessageMeUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required WhoCanMessageMe value}) {
    return _repository.updateSettings(uid, {'whoCanMessageMe': value.name});
  }
}
