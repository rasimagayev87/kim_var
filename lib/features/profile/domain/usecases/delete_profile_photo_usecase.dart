import '../repositories/storage_repository.dart';
import '../storage_failure.dart';

/// Deletes the current user's profile photo from storage.
class DeleteProfilePhotoUseCase {
  final StorageRepository _repository;

  const DeleteProfilePhotoUseCase(this._repository);

  Future<void> call({required String userId}) async {
    if (userId.isEmpty) {
      throw const StorageException(
        StorageFailure.unauthenticated,
        'İstifadəçi daxil olmayıb.',
      );
    }

    try {
      await _repository.deleteProfilePhoto(userId: userId);
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageException(
        StorageFailure.deleteFailed,
        'Şəkil silinə bilmədi.',
        cause: e,
      );
    }
  }
}
