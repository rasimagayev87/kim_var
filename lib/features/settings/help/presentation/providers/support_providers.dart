import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/app_logger.dart';
import '../../data/repositories/firebase_support_repository.dart';
import '../../domain/entities/support_message.dart';
import '../../domain/repositories/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => FirebaseSupportRepository(),
);

class SupportController {
  SupportController(this._ref);

  final Ref _ref;

  Future<bool> sendMessage(SupportMessageType type, String message) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _ref
          .read(supportRepositoryProvider)
          .sendMessage(uid: uid, type: type, message: message);
      return true;
    } catch (e, st) {
      logError('support_providers.SupportController.sendMessage', e, st);
      return false;
    }
  }
}

final supportControllerProvider = Provider<SupportController>(
  (ref) => SupportController(ref),
);
