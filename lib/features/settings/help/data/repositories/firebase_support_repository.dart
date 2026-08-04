import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/support_message.dart';
import '../../domain/repositories/support_repository.dart';

class FirebaseSupportRepository implements SupportRepository {
  FirebaseSupportRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> sendMessage({
    required String uid,
    required SupportMessageType type,
    required String message,
  }) async {
    final info = await PackageInfo.fromPlatform();
    await _firestore.collection('supportMessages').add({
      'uid': uid,
      'type': type.name,
      'message': message,
      'appVersion': info.version,
      'platform': Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : Platform.operatingSystem),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
