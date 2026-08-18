import 'dart:io';

import '../entities/identity_verification_request.dart';

abstract class IdentityVerificationRepository {
  /// The signed-in user's own most recent request, if any — `null`
  /// means they've never submitted one. Live (Firestore snapshots), so
  /// an admin's approve/reject shows up without the user reopening the
  /// screen.
  Stream<IdentityVerificationRequest?> watchLatestRequest(String userId);

  /// Uploads all three images to Storage, then calls
  /// `submitIdentityVerification` (Cloud Function) to create the
  /// review record — see that function's doc comment for why creation
  /// itself can't be a direct Firestore write.
  Future<void> submit({
    required String userId,
    required File idFront,
    required File idBack,
    required File selfieWithId,
    void Function(double progress)? onProgress,
  });
}
