import '../entities/privacy_settings.dart';
import '../repositories/privacy_settings_repository.dart';

/// Sets [AccountPrivacy] — see its doc comment for everything this
/// single field now gates (media, follow/follower lists, avatar tap,
/// the follow flow, new stories' default visibility).
class UpdateAccountPrivacyUseCase {
  const UpdateAccountPrivacyUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required AccountPrivacy privacy}) {
    return _repository.updateSettings(uid, {'accountPrivacy': privacy.name});
  }
}
