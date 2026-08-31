import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/utils/exif_stripper.dart';
import '../../../../core/utils/storage_deletion.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/storage_failure.dart';

/// Firebase Storage implementation of [StorageRepository].
///
/// Stores profile photos at `profile_photos/{userId}/profile.jpg`, matching
/// the published security rule path `profile_photos/{userId}/{fileName}`
/// (owner-only writes, 5MB limit, image/* content-type).
class FirebaseStorageRepository implements StorageRepository {
  final FirebaseStorage _storage;

  FirebaseStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  String _pathFor(String userId) => 'profile_photos/$userId/profile.jpg';

  String _contentTypeFor(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(_pathFor(userId));

    try {
      // GPS EXIF strip (Düzəliş Prompt 3 / C#43) — profile photos are
      // the single highest-priority case here, since a leaked GPS tag
      // on one directly reveals a home address.
      final stripped = await stripExifIfImage(file);
      final task = ref.putFile(
        stripped,
        SettableMetadata(contentType: _contentTypeFor(stripped.path)),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
      }

      await task;
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw _mapException(e, fallback: StorageFailure.uploadFailed);
    }
  }

  @override
  Future<void> deleteProfilePhoto({required String userId}) async {
    try {
      await deleteWithResizedVariant(_storage.ref(_pathFor(userId)));
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw _mapException(e, fallback: StorageFailure.deleteFailed);
    }
  }

  @override
  Future<String> getProfilePhotoDownloadUrl({required String userId}) async {
    try {
      return await _storage.ref(_pathFor(userId)).getDownloadURL();
    } on FirebaseException catch (e) {
      throw _mapException(e, fallback: StorageFailure.downloadUrlFailed);
    }
  }

  StorageException _mapException(FirebaseException e, {required StorageFailure fallback}) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return StorageException(
          StorageFailure.permissionDenied,
          'Bu əməliyyat üçün icazəniz yoxdur.',
          cause: e,
        );
      case 'unauthenticated':
        return StorageException(
          StorageFailure.unauthenticated,
          'İstifadəçi daxil olmayıb.',
          cause: e,
        );
      default:
        return StorageException(fallback, e.message ?? 'Naməlum Storage xətası.', cause: e);
    }
  }
}
