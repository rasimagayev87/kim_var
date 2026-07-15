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

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneAutoVerified onAutoVerified,
    required PhoneVerificationFailed onFailed,
  }) {
    return _repository.startPhoneVerification(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onAutoVerified: (user, isNewUser) {
        if (!isNewUser) state = AsyncValue.data(user);
        onAutoVerified(user, isNewUser);
      },
      onFailed: onFailed,
    );
  }

  Future<(AppUser, bool)> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      state = result.$2 ? const AsyncValue.data(null) : AsyncValue.data(result.$1);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<(AppUser, bool)> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.signInWithGoogle();
      state = result.$2 ? const AsyncValue.data(null) : AsyncValue.data(result.$1);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<(AppUser, bool)> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.signInWithApple();
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
    List<String> interests = const [],
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
        interests: interests,
      ),
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }
}
