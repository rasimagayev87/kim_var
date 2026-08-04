import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../domain/entities/device_session.dart';
import '../../domain/repositories/device_session_repository.dart';

class FirebaseDeviceSessionRepository implements DeviceSessionRepository {
  FirebaseDeviceSessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _deviceInfo = DeviceInfoPlugin();

  /// A stable-per-install id, so repeated `touchCurrentSession` calls
  /// from the SAME device update one doc instead of creating a new
  /// session entry every app resume. Platform+model isn't guaranteed
  /// unique across two identical physical devices, but combined with
  /// being scoped under the signed-in user's own `sessions`
  /// subcollection, collisions are not a practical concern for "which
  /// of MY devices is this".
  String? _cachedSessionId;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  @override
  Stream<List<DeviceSession>> watchSessions(String uid) {
    return _sessions(uid).orderBy('lastActiveAt', descending: true).snapshots().asyncMap((snap) async {
      final currentId = await _sessionId();
      return snap.docs.map((d) => _fromDoc(d.id, d.data(), currentId)).toList();
    });
  }

  @override
  Future<void> touchCurrentSession(String uid) async {
    final id = await _sessionId();
    final deviceName = await _deviceName();

    await _sessions(uid).doc(id).set(
      {
        'deviceName': deviceName,
        'platform': Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : Platform.operatingSystem),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeSession(String uid, String sessionId) {
    return _sessions(uid).doc(sessionId).delete();
  }

  @override
  Future<String> currentSessionId() => _sessionId();

  Future<String> _sessionId() async {
    if (_cachedSessionId != null) return _cachedSessionId!;

    String id;
    try {
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        id = info.identifierForVendor ?? 'ios-unknown';
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        id = info.id;
      } else {
        id = Platform.operatingSystem;
      }
    } catch (_) {
      id = 'device-${DateTime.now().millisecondsSinceEpoch}';
    }

    _cachedSessionId = id;
    return id;
  }

  Future<String> _deviceName() async {
    try {
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.name.isNotEmpty ? info.name : info.model;
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }
    } catch (_) {
      // Falls through to the generic platform-name fallback below.
    }
    return Platform.operatingSystem;
  }

  DeviceSession _fromDoc(String id, Map<String, dynamic> data, String currentSessionId) {
    return DeviceSession(
      id: id,
      deviceName: data['deviceName'] as String? ?? '',
      platform: data['platform'] as String? ?? '',
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCurrentDevice: id == currentSessionId,
    );
  }
}
