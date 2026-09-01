import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../profile/domain/storage_failure.dart';
import '../../domain/entities/identity_verification_request.dart';
import '../../domain/repositories/identity_verification_repository.dart';

import '../../../../core/utils/callables.dart';

/// Stores images at `identity_verifications/{userId}/{requestId}/...`
/// (matching storage.rules) and, unlike [FirebaseStorageRepository]
/// (profile photos), never calls `getDownloadURL()` — that call
/// returns a token-bearing URL that works regardless of security
/// rules, which is exactly what this collection must never produce.
/// Only the Storage PATH is ever passed onward (to
/// `submitIdentityVerification`), never a URL.
class FirebaseIdentityVerificationRepository implements IdentityVerificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  FirebaseIdentityVerificationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Stream<IdentityVerificationRequest?> watchLatestRequest(String userId) {
    return _firestore
        .collection('identityVerifications')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final data = doc.data();
      return IdentityVerificationRequest(
        id: doc.id,
        status: identityVerificationStatusFromString(data['status'] as String? ?? 'pending'),
        rejectionReason: data['rejectionReason'] as String?,
        submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      );
    });
  }

  @override
  Future<void> submit({
    required String userId,
    required File idFront,
    required File idBack,
    required File selfieWithId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final requestId = _firestore.collection('identityVerifications').doc().id;
      final basePath = 'identity_verifications/$userId/$requestId';

      final progressByKey = <String, double>{'front': 0, 'back': 0, 'selfie': 0};
      void reportProgress() {
        if (onProgress == null) return;
        final avg = (progressByKey['front']! + progressByKey['back']! + progressByKey['selfie']!) / 3;
        onProgress(avg);
      }

      Future<String> upload(String key, File file, String fileName) async {
        final ref = _storage.ref('$basePath/$fileName');
        final task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            progressByKey[key] = snapshot.bytesTransferred / snapshot.totalBytes;
            reportProgress();
          }
        });
        await task;
        return ref.fullPath;
      }

      final paths = await Future.wait([
        upload('front', idFront, 'id_front.jpg'),
        upload('back', idBack, 'id_back.jpg'),
        upload('selfie', selfieWithId, 'selfie_with_id.jpg'),
      ]);

      await _functions.httpsCallable('submitIdentityVerification', options: callableOptions()).call<Map<String, dynamic>>({
        'requestId': requestId,
        'idFrontPath': paths[0],
        'idBackPath': paths[1],
        'selfieWithIdPath': paths[2],
      });
    } on FirebaseFunctionsException catch (e) {
      throw StorageException(
        e.code == 'failed-precondition' ? StorageFailure.uploadFailed : StorageFailure.unknown,
        e.message ?? e.code,
        cause: e,
      );
    } on FirebaseException catch (e) {
      throw _mapStorageException(e);
    }
  }

  StorageException _mapStorageException(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return StorageException(StorageFailure.permissionDenied, 'Bu əməliyyat üçün icazəniz yoxdur.', cause: e);
      case 'canceled':
        return StorageException(StorageFailure.uploadFailed, 'Yükləmə ləğv edildi.', cause: e);
      default:
        return StorageException(StorageFailure.uploadFailed, 'Yükləmə uğursuz oldu: ${e.message}', cause: e);
    }
  }
}
