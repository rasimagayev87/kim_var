import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/domain/storage_failure.dart';
import '../../data/repositories/firebase_identity_verification_repository.dart';
import '../../domain/entities/identity_verification_request.dart';
import '../../domain/repositories/identity_verification_repository.dart';

final identityVerificationRepositoryProvider = Provider<IdentityVerificationRepository>((ref) {
  return FirebaseIdentityVerificationRepository();
});

/// The signed-in user's own most recent request — `null` (no data yet,
/// not loading) means they've never submitted one. autoDispose since
/// this only matters while [IdentityVerificationScreen] is open.
final latestIdentityVerificationRequestProvider =
    StreamProvider.autoDispose<IdentityVerificationRequest?>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(identityVerificationRepositoryProvider).watchLatestRequest(uid);
});

enum IdentityVerificationSubmitStatus { idle, loading, success, error }

class IdentityVerificationSubmitState {
  final IdentityVerificationSubmitStatus status;
  final double progress;
  final StorageFailure? failureType;
  final String? errorMessage;

  const IdentityVerificationSubmitState._({
    required this.status,
    this.progress = 0,
    this.failureType,
    this.errorMessage,
  });

  const IdentityVerificationSubmitState.idle() : this._(status: IdentityVerificationSubmitStatus.idle);

  const IdentityVerificationSubmitState.loading([double progress = 0])
      : this._(status: IdentityVerificationSubmitStatus.loading, progress: progress);

  const IdentityVerificationSubmitState.success()
      : this._(status: IdentityVerificationSubmitStatus.success, progress: 1);

  const IdentityVerificationSubmitState.error(StorageFailure type, String message)
      : this._(status: IdentityVerificationSubmitStatus.error, failureType: type, errorMessage: message);

  bool get isLoading => status == IdentityVerificationSubmitStatus.loading;
}

final identityVerificationSubmitControllerProvider = StateNotifierProvider.autoDispose<
    IdentityVerificationSubmitController, IdentityVerificationSubmitState>((ref) {
  return IdentityVerificationSubmitController(ref.watch(identityVerificationRepositoryProvider));
});

class IdentityVerificationSubmitController extends StateNotifier<IdentityVerificationSubmitState> {
  final IdentityVerificationRepository _repository;
  final fb.FirebaseAuth _auth;

  IdentityVerificationSubmitController(this._repository, {fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        super(const IdentityVerificationSubmitState.idle());

  /// Returns true on success — the caller clears its picked-image
  /// state only then, so a failed submit leaves the 3 pictures in
  /// place for the user to just retry instead of re-picking everything.
  Future<bool> submit({required File idFront, required File idBack, required File selfieWithId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      state = const IdentityVerificationSubmitState.error(StorageFailure.unauthenticated, 'İstifadəçi daxil olmayıb.');
      return false;
    }

    state = const IdentityVerificationSubmitState.loading(0);
    try {
      await _repository.submit(
        userId: uid,
        idFront: idFront,
        idBack: idBack,
        selfieWithId: selfieWithId,
        onProgress: (p) {
          if (mounted) state = IdentityVerificationSubmitState.loading(p);
        },
      );
      if (!mounted) return true;
      state = const IdentityVerificationSubmitState.success();
      return true;
    } on StorageException catch (e) {
      if (!mounted) return false;
      state = IdentityVerificationSubmitState.error(e.type, e.message);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = IdentityVerificationSubmitState.error(StorageFailure.unknown, 'Gözlənilməz xəta: $e');
      return false;
    }
  }

  void reset() {
    if (mounted) state = const IdentityVerificationSubmitState.idle();
  }
}
