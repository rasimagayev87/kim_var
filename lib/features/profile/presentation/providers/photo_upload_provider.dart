import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_storage_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/storage_failure.dart';
import '../../domain/usecases/delete_profile_photo_usecase.dart';
import '../../domain/usecases/upload_profile_photo_usecase.dart';
import 'profile_providers.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return FirebaseStorageRepository();
});

final uploadProfilePhotoUseCaseProvider = Provider<UploadProfilePhotoUseCase>((ref) {
  return UploadProfilePhotoUseCase(ref.watch(storageRepositoryProvider));
});

final deleteProfilePhotoUseCaseProvider = Provider<DeleteProfilePhotoUseCase>((ref) {
  return DeleteProfilePhotoUseCase(ref.watch(storageRepositoryProvider));
});

final photoUploadControllerProvider =
    StateNotifierProvider<PhotoUploadController, PhotoUploadState>((ref) {
  return PhotoUploadController(
    uploadUseCase: ref.watch(uploadProfilePhotoUseCaseProvider),
    deleteUseCase: ref.watch(deleteProfilePhotoUseCaseProvider),
    onPhotoUrlChanged: (url) => ref.read(profileControllerProvider.notifier).updatePhotoUrl(url),
  );
});

enum PhotoUploadStatus { idle, loading, success, error }

class PhotoUploadState {
  final PhotoUploadStatus status;
  final double progress;
  final String? photoUrl;
  final StorageFailure? failureType;
  final String? errorMessage;

  const PhotoUploadState._({
    required this.status,
    this.progress = 0,
    this.photoUrl,
    this.failureType,
    this.errorMessage,
  });

  const PhotoUploadState.idle() : this._(status: PhotoUploadStatus.idle);

  const PhotoUploadState.loading([double progress = 0])
      : this._(status: PhotoUploadStatus.loading, progress: progress);

  const PhotoUploadState.success(String photoUrl)
      : this._(status: PhotoUploadStatus.success, photoUrl: photoUrl, progress: 1);

  const PhotoUploadState.error(StorageFailure type, String message)
      : this._(status: PhotoUploadStatus.error, failureType: type, errorMessage: message);

  bool get isLoading => status == PhotoUploadStatus.loading;
}

/// Drives profile-photo upload/removal: validates + uploads via
/// [UploadProfilePhotoUseCase], then persists the resulting URL to
/// Firestore through [onPhotoUrlChanged] (wired to
/// [ProfileController.updatePhotoUrl]).
class PhotoUploadController extends StateNotifier<PhotoUploadState> {
  final UploadProfilePhotoUseCase _uploadUseCase;
  final DeleteProfilePhotoUseCase _deleteUseCase;
  final Future<void> Function(String? url) _onPhotoUrlChanged;
  final fb.FirebaseAuth _auth;

  PhotoUploadController({
    required UploadProfilePhotoUseCase uploadUseCase,
    required DeleteProfilePhotoUseCase deleteUseCase,
    required Future<void> Function(String? url) onPhotoUrlChanged,
    fb.FirebaseAuth? auth,
  })  : _uploadUseCase = uploadUseCase,
        _deleteUseCase = deleteUseCase,
        _onPhotoUrlChanged = onPhotoUrlChanged,
        _auth = auth ?? fb.FirebaseAuth.instance,
        super(const PhotoUploadState.idle());

  Future<void> upload(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      state = const PhotoUploadState.error(StorageFailure.unauthenticated, 'İstifadəçi daxil olmayıb.');
      return;
    }

    state = const PhotoUploadState.loading(0);
    try {
      final url = await _uploadUseCase(
        userId: uid,
        file: file,
        onProgress: (p) {
          if (mounted) state = PhotoUploadState.loading(p);
        },
      );
      await _onPhotoUrlChanged(url);
      if (!mounted) return;
      state = PhotoUploadState.success(url);
    } on StorageException catch (e) {
      if (!mounted) return;
      state = PhotoUploadState.error(e.type, e.message);
    } catch (e) {
      if (!mounted) return;
      state = PhotoUploadState.error(StorageFailure.unknown, 'Gözlənilməz xəta: $e');
    }
  }

  Future<void> remove() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      state = const PhotoUploadState.error(StorageFailure.unauthenticated, 'İstifadəçi daxil olmayıb.');
      return;
    }

    state = const PhotoUploadState.loading(0);
    try {
      await _deleteUseCase(userId: uid);
      await _onPhotoUrlChanged(null);
      if (!mounted) return;
      state = const PhotoUploadState.idle();
    } on StorageException catch (e) {
      if (!mounted) return;
      state = PhotoUploadState.error(e.type, e.message);
    } catch (e) {
      if (!mounted) return;
      state = PhotoUploadState.error(StorageFailure.unknown, 'Gözlənilməz xəta: $e');
    }
  }

  void reset() {
    if (mounted) state = const PhotoUploadState.idle();
  }
}
