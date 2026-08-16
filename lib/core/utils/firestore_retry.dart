import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore's SDK doesn't always finish propagating a just-changed auth
/// context (signing in as a different user right after a prior sign-out,
/// most commonly) to its underlying connection before the very next read
/// goes out — that read can land as a transient `permission-denied` even
/// though the security rule is satisfied a moment later. Retries a couple
/// of times with a short backoff before giving up for real.
///
/// Same shape as `FirebaseAuthRepository._writeUsernameReservationWithRetry`,
/// which already applies this to the equivalent write-side race — this is
/// the read-side counterpart, shared since multiple repositories need it.
Future<T> withPermissionRetry<T>(Future<T> Function() action) async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' || attempt == maxAttempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
  }
  throw StateError('unreachable');
}
