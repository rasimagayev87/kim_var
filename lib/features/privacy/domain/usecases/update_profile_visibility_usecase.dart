import '../entities/privacy_settings.dart';
import '../repositories/privacy_settings_repository.dart';

/// Sets who can see this user's profile MEDIA — see
/// [ProfileVisibility]'s doc comment. Unrelated to Ghost Mode, which
/// has its own [UpdateGhostModeUseCase].
class UpdateProfileVisibilityUseCase {
  const UpdateProfileVisibilityUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required ProfileVisibility visibility}) {
    // Flat field on users/{uid} — matches the existing convention there
    // (blockedUsers, premium, online, ...) rather than introducing a
    // nested `privacy` map.
    return _repository.updateSettings(uid, {'profileVisibility': visibility.name});
  }
}
