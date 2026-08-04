import 'dart:io';

/// Abstraction over the storage backend used for profile photos.
/// Implemented by [FirebaseStorageRepository] in the data layer.
abstract class StorageRepository {
  /// Uploads [file] as the profile photo for [userId] and returns its
  /// public download URL. [onProgress] is called with a value in [0, 1]
  /// as bytes are transferred.
  Future<String> uploadProfilePhoto({
    required String userId,
    required File file,
    void Function(double progress)? onProgress,
  });

  /// Deletes the profile photo for [userId], if one exists.
  Future<void> deleteProfilePhoto({required String userId});

  /// Returns the current download URL for [userId]'s profile photo.
  Future<String> getProfilePhotoDownloadUrl({required String userId});
}
