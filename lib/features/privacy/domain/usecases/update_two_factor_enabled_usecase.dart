import '../repositories/privacy_settings_repository.dart';

/// Phase 3 — see the phase-plan note on 2FA: this usecase only flips the
/// `twoFactorEnabled` flag on the user doc. It deliberately does *not*
/// implement an actual second factor yet (no SMS-on-top-of-SMS flow, no
/// TOTP/Authenticator enrollment) — this app's only sign-in method is
/// already phone/OTP, so a real 2FA design needs a second, independent
/// factor (e.g. a TOTP secret) and its own enrollment/verification UI,
/// which is a separate decision to make before building, not something
/// to bolt on silently.
class UpdateTwoFactorEnabledUseCase {
  const UpdateTwoFactorEnabledUseCase(this._repository);

  final PrivacySettingsRepository _repository;

  Future<void> call({required String uid, required bool enabled}) {
    return _repository.updateSettings(uid, {'twoFactorEnabled': enabled});
  }
}
