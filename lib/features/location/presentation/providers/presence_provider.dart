import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the signed-in user's `online` flag and `lastSeen`
/// timestamp in Firestore up to date as the app moves through its
/// lifecycle (foreground/background), so other users see accurate
/// presence — no fake "always online" state.
final presenceControllerProvider = Provider<PresenceController>((ref) {
  return PresenceController();
});

class PresenceController {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  PresenceController({FirebaseFirestore? firestore, fb.FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  Future<void> setOnline() => _set(true);

  Future<void> setOffline() => _set(false);

  Future<void> _set(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      {
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
