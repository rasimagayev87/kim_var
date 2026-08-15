import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_account_repository.dart';
import '../../data/repositories/firebase_device_session_repository.dart';
import '../../data/repositories/firebase_privacy_settings_repository.dart';
import '../../domain/entities/device_session.dart';
import '../../domain/entities/privacy_settings.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/device_session_repository.dart';
import '../../domain/repositories/privacy_settings_repository.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/export_user_data_usecase.dart';
import '../../domain/usecases/update_account_privacy_usecase.dart';
import '../../domain/usecases/update_birthday_offers_opt_in_usecase.dart';
import '../../domain/usecases/update_ghost_mode_usecase.dart';
import '../../domain/usecases/update_profile_visibility_usecase.dart';
import '../../domain/usecases/update_show_online_status_usecase.dart';
import '../../domain/usecases/update_show_read_receipts_usecase.dart';
import '../../domain/usecases/update_two_factor_enabled_usecase.dart';
import '../../domain/usecases/update_visibility_radius_usecase.dart';
import '../../domain/usecases/update_who_can_message_me_usecase.dart';

final privacySettingsRepositoryProvider = Provider<PrivacySettingsRepository>((ref) {
  return FirebasePrivacySettingsRepository();
});

final updateProfileVisibilityUseCaseProvider = Provider<UpdateProfileVisibilityUseCase>((ref) {
  return UpdateProfileVisibilityUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateAccountPrivacyUseCaseProvider = Provider<UpdateAccountPrivacyUseCase>((ref) {
  return UpdateAccountPrivacyUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateVisibilityRadiusUseCaseProvider = Provider<UpdateVisibilityRadiusUseCase>((ref) {
  return UpdateVisibilityRadiusUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateShowOnlineStatusUseCaseProvider = Provider<UpdateShowOnlineStatusUseCase>((ref) {
  return UpdateShowOnlineStatusUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateShowReadReceiptsUseCaseProvider = Provider<UpdateShowReadReceiptsUseCase>((ref) {
  return UpdateShowReadReceiptsUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateWhoCanMessageMeUseCaseProvider = Provider<UpdateWhoCanMessageMeUseCase>((ref) {
  return UpdateWhoCanMessageMeUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateTwoFactorEnabledUseCaseProvider = Provider<UpdateTwoFactorEnabledUseCase>((ref) {
  return UpdateTwoFactorEnabledUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateGhostModeUseCaseProvider = Provider<UpdateGhostModeUseCase>((ref) {
  return UpdateGhostModeUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final updateBirthdayOffersOptInUseCaseProvider = Provider<UpdateBirthdayOffersOptInUseCase>((ref) {
  return UpdateBirthdayOffersOptInUseCase(ref.watch(privacySettingsRepositoryProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) => FirebaseAccountRepository());

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(accountRepositoryProvider));
});

final exportUserDataUseCaseProvider = Provider<ExportUserDataUseCase>((ref) {
  return ExportUserDataUseCase(ref.watch(accountRepositoryProvider));
});

String? _currentUid() => fb.FirebaseAuth.instance.currentUser?.uid;

final privacySettingsProvider = StreamProvider<PrivacySettings>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const PrivacySettings());
  return ref.watch(privacySettingsRepositoryProvider).watchSettings(uid);
});

/// Same data, for an arbitrary OTHER user — what `UserProfileScreen`
/// reads to decide whether it's allowed to show that person's media.
final otherUserPrivacySettingsProvider = StreamProvider.autoDispose.family<PrivacySettings, String>((ref, uid) {
  return ref.watch(privacySettingsRepositoryProvider).watchSettings(uid);
});

/// Every write from the Privacy & Security screen goes through here.
/// Never throws — same "log internally, tell the user one friendly
/// thing" contract as `ChatController`/`EventController`: the screen
/// doesn't need its own try/catch per switch.
class PrivacySettingsController {
  PrivacySettingsController(this._ref);

  final Ref _ref;

  Future<bool> updateProfileVisibility(ProfileVisibility visibility) {
    return _run((uid) => _ref.read(updateProfileVisibilityUseCaseProvider).call(uid: uid, visibility: visibility));
  }

  Future<bool> updateAccountPrivacy(AccountPrivacy privacy) {
    return _run((uid) => _ref.read(updateAccountPrivacyUseCaseProvider).call(uid: uid, privacy: privacy));
  }

  Future<bool> updateVisibilityRadius(VisibilityRadiusMode mode, {double? radiusKm}) {
    return _run((uid) => _ref.read(updateVisibilityRadiusUseCaseProvider).call(uid: uid, mode: mode, radiusKm: radiusKm));
  }

  Future<bool> updateShowOnlineStatus(bool show) {
    return _run((uid) => _ref.read(updateShowOnlineStatusUseCaseProvider).call(uid: uid, show: show));
  }

  Future<bool> updateShowReadReceipts(bool show) {
    return _run((uid) => _ref.read(updateShowReadReceiptsUseCaseProvider).call(uid: uid, show: show));
  }

  Future<bool> updateWhoCanMessageMe(WhoCanMessageMe value) {
    return _run((uid) => _ref.read(updateWhoCanMessageMeUseCaseProvider).call(uid: uid, value: value));
  }

  Future<bool> updateTwoFactorEnabled(bool enabled) {
    return _run((uid) => _ref.read(updateTwoFactorEnabledUseCaseProvider).call(uid: uid, enabled: enabled));
  }

  Future<bool> updateGhostMode(bool enabled) {
    return _run((uid) => _ref.read(updateGhostModeUseCaseProvider).call(uid: uid, enabled: enabled));
  }

  Future<bool> updateBirthdayOffersOptIn(bool enabled) {
    return _run((uid) => _ref.read(updateBirthdayOffersOptInUseCaseProvider).call(uid: uid, enabled: enabled));
  }

  Future<bool> _run(Future<void> Function(String uid) action) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await action(uid);
      return true;
    } catch (e, st) {
      logError('privacy_providers.PrivacySettingsController', e, st);
      return false;
    }
  }
}

final privacySettingsControllerProvider = Provider<PrivacySettingsController>((ref) {
  return PrivacySettingsController(ref);
});

/// Drives "Məlumatlarımı yüklə" / "Hesabı sil". Unlike
/// [PrivacySettingsController], [deleteAccount] deliberately lets
/// [ReauthenticationRequiredException] propagate instead of swallowing
/// it — the screen needs to react to that one specifically (open the
/// reauth dialog), not treat it as a generic failure.
class AccountController {
  AccountController(this._ref);

  final Ref _ref;

  Future<void> deleteAccount() {
    return _ref.read(deleteAccountUseCaseProvider).call();
  }

  /// Returns the exported JSON, or null on failure (logged internally).
  Future<String?> exportUserData() async {
    try {
      return await _ref.read(exportUserDataUseCaseProvider).call();
    } catch (e, st) {
      logError('privacy_providers.AccountController.exportUserData', e, st);
      return null;
    }
  }

  Future<void> sendReauthCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onFailed,
  }) {
    return _ref.read(accountRepositoryProvider).sendReauthCode(
          phoneNumber: phoneNumber,
          onCodeSent: onCodeSent,
          onFailed: onFailed,
        );
  }

  Future<void> confirmReauthCode({required String verificationId, required String smsCode}) {
    return _ref.read(accountRepositoryProvider).confirmReauthCode(verificationId: verificationId, smsCode: smsCode);
  }

  /// Returns true on success (logged internally on failure).
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _ref.read(accountRepositoryProvider).updateEmail(newEmail);
      return true;
    } catch (e, st) {
      logError('privacy_providers.AccountController.updateEmail', e, st);
      return false;
    }
  }
}

final accountControllerProvider = Provider<AccountController>((ref) => AccountController(ref));

final deviceSessionRepositoryProvider = Provider<DeviceSessionRepository>((ref) {
  return FirebaseDeviceSessionRepository();
});

/// "Aktiv cihazlar" list. [touchOwnSessionProvider] is what keeps the
/// current device's own entry in this list fresh — this provider only
/// watches, it doesn't write.
final deviceSessionsProvider = StreamProvider.autoDispose<List<DeviceSession>>((ref) {
  final uid = _currentUid();
  if (uid == null) return Stream.value(const []);
  return ref.watch(deviceSessionRepositoryProvider).watchSessions(uid);
});

class DeviceSessionController {
  DeviceSessionController(this._ref);

  final Ref _ref;

  Future<void> touchCurrentSession() async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      await _ref.read(deviceSessionRepositoryProvider).touchCurrentSession(uid);
    } catch (e, st) {
      logError('privacy_providers.DeviceSessionController.touchCurrentSession', e, st);
    }
  }

  /// Returns true on success (logged internally on failure). This only
  /// removes the OTHER device's Firestore session doc — see
  /// [DeviceSession]'s doc comment for why that alone doesn't force it
  /// offline; [SessionGuard] is what makes that device notice and sign
  /// itself out.
  Future<bool> removeSession(String sessionId) async {
    final uid = _currentUid();
    if (uid == null) return false;
    try {
      await _ref.read(deviceSessionRepositoryProvider).removeSession(uid, sessionId);
      return true;
    } catch (e, st) {
      logError('privacy_providers.DeviceSessionController.removeSession', e, st);
      return false;
    }
  }
}

final deviceSessionControllerProvider = Provider<DeviceSessionController>((ref) => DeviceSessionController(ref));
