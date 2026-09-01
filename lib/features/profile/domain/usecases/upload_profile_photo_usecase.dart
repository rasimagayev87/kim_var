import 'dart:io';

import '../repositories/storage_repository.dart';
import '../storage_failure.dart';

/// Validates and uploads a profile photo, returning its download URL.
class UploadProfilePhotoUseCase {
  final StorageRepository _repository;

  const UploadProfilePhotoUseCase(this._repository);

  /// Matches the 5MB limit enforced by the published Firebase Storage
  /// security rule for `profile_photos/{userId}/{fileName}`.
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  static const _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  Future<String> call({
    required String userId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    if (userId.isEmpty) {
      throw const StorageException(
        StorageFailure.unauthenticated,
        'İstifadəçi daxil olmayıb.',
      );
    }

    if (!await file.exists()) {
      throw const StorageException(
        StorageFailure.uploadFailed,
        'Şəkil faylı tapılmadı.',
      );
    }

    final sizeBytes = await file.length();
    if (sizeBytes > maxFileSizeBytes) {
      throw const StorageException(
        StorageFailure.fileTooLarge,
        'Şəkil 5MB-dan böyük ola bilməz.',
      );
    }
    if (sizeBytes == 0) {
      throw const StorageException(
        StorageFailure.uploadFailed,
        'Şəkil faylı boşdur.',
      );
    }

    final extension = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw StorageException(
        StorageFailure.invalidContentType,
        'Dəstəklənməyən fayl formatı: .$extension',
      );
    }

    try {
      return await _repository.uploadProfilePhoto(
        userId: userId,
        file: file,
        onProgress: onProgress,
      );
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageException(
        StorageFailure.uploadFailed,
        'Şəkil yüklənə bilmədi.',
        cause: e,
      );
    }
  }
}
