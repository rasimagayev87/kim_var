import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _restore();
  }

  bool get needsOnboarding => _repository.needsOnboarding;

  Future<void> _restore() async {
    state = await AsyncValue.guard(() => _repository.restoreSession());
  }

  Future<bool> isUsernameAvailable(String username) {
    return _repository.isUsernameAvailable(username);
  }

  Future<void> registerWithUsername({
    required String username,
    required String password,
  }) {
    return _repository.registerWithUsername(username: username, password: password);
  }

  Future<(AppUser, bool)> loginWithUsername({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.loginWithUsername(username: username, password: password);
      state = result.$2 ? const AsyncValue.data(null) : AsyncValue.data(result.$1);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    String? bio,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.completeOnboarding(
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        gender: gender,
        country: country,
        city: city,
        bio: bio,
      ),
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<bool> isPhoneNumberTaken(String phoneNumber) {
    return _repository.isPhoneNumberTaken(phoneNumber);
  }

  Future<void> startPhoneLinkVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  }) {
    return _repository.startPhoneLinkVerification(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onAutoVerified: onAutoVerified,
      onFailed: onFailed,
    );
  }

  Future<void> confirmPhoneLink({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) {
    return _repository.confirmPhoneLink(
      verificationId: verificationId,
      smsCode: smsCode,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> sendTwilioOtp(String phoneNumber) {
    return _repository.sendTwilioOtp(phoneNumber);
  }

  Future<void> verifyTwilioOtp({
    required String phoneNumber,
    required String code,
  }) {
    return _repository.verifyTwilioOtp(phoneNumber: phoneNumber, code: code);
  }

  Future<void> startPhoneRecoveryVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String? errorCode) onFailed,
  }) {
    return _repository.startPhoneRecoveryVerification(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onAutoVerified: onAutoVerified,
      onFailed: onFailed,
    );
  }

  Future<void> confirmPhoneRecovery({
    required String verificationId,
    required String smsCode,
  }) {
    return _repository.confirmPhoneRecovery(verificationId: verificationId, smsCode: smsCode);
  }

  Future<void> updatePassword(String newPassword) {
    return _repository.updatePassword(newPassword);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  }) {
    return _repository.updateUsername(oldUsername: oldUsername, newUsername: newUsername);
  }
}
