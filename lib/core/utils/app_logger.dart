import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Logs [error] (and [stackTrace] if given) to the console/DevTools under
/// a consistent tag, instead of ever surfacing it raw to users — Firebase
/// exceptions in particular ("[cloud_firestore/permission-denied] ...")
/// are diagnostic detail, not something a user should ever read.
void logError(String context, Object error, [StackTrace? stackTrace]) {
  developer.log(
    error.toString(),
    name: 'meevima.$context',
    error: error,
    stackTrace: stackTrace,
    level: 1000, // SEVERE
  );
}

/// True when [error] is a Firestore/Storage permission-denied failure —
/// almost always a stale/signed-out session or (mid-development) security
/// rules that haven't been deployed yet, so it deserves a clearer message
/// than a generic "something went wrong".
bool isPermissionDeniedError(Object error) {
  return error is FirebaseException && error.code == 'permission-denied';
}

/// True when [error] is Firestore's "couldn't reach the backend" failure
/// — the closest thing to a clean offline signal this app gets without a
/// dedicated connectivity package, since Firestore normally serves reads
/// from its local cache instead of throwing when the device is offline.
bool isOfflineError(Object error) {
  return error is FirebaseException && (error.code == 'unavailable' || error.code == 'network-request-failed');
}
