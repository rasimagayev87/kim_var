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

  Future<(AppUser, bool)> _runSignIn(Future<(AppUser, bool)> Function() signIn) async {
    state = const AsyncValue.loading();
    try {
      final result = await signIn();
      state = result.$2 ? const AsyncValue.data(null) : AsyncValue.data(result.$1);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<(AppUser, bool)> signInWithApple() => _runSignIn(_repository.signInWithApple);

  Future<(AppUser, bool)> signInWithGoogle() => _runSignIn(_repository.signInWithGoogle);

  Future<(AppUser, bool)> signInWithEmailPassword(String email, String password) {
    return _runSignIn(() => _repository.signInWithEmailPassword(email, password));
  }

  Future<(AppUser, bool)> registerWithEmailPassword(String email, String password) {
    return _runSignIn(() => _repository.registerWithEmailPassword(email, password));
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _repository.sendPasswordResetEmail(email);
  }

  Future<void> resendEmailVerification() {
    return _repository.resendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() {
    return _repository.reloadAndCheckEmailVerified();
  }

  Future<void> completeOnboarding({
    required String username,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String country,
    required String city,
    required String phoneNumber,
    required String businessStatus,
    String? bio,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.completeOnboarding(
        username: username,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        gender: gender,
        country: country,
        city: city,
        phoneNumber: phoneNumber,
        businessStatus: businessStatus,
        bio: bio,
      ),
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateUsername({
    required String oldUsername,
    required String newUsername,
  }) {
    return _repository.updateUsername(oldUsername: oldUsername, newUsername: newUsername);
  }
}
