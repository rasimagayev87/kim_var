import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase_safety_repository.dart';
import '../../domain/safety_repository.dart';
import '../../domain/usecases/block_user_usecase.dart';
import '../../domain/usecases/report_user_usecase.dart';
import '../../domain/usecases/unblock_user_usecase.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) => FirebaseSafetyRepository());

final blockUserUseCaseProvider = Provider<BlockUserUseCase>((ref) {
  return BlockUserUseCase(ref.watch(safetyRepositoryProvider));
});

final unblockUserUseCaseProvider = Provider<UnblockUserUseCase>((ref) {
  return UnblockUserUseCase(ref.watch(safetyRepositoryProvider));
});

final reportUserUseCaseProvider = Provider<ReportUserUseCase>((ref) {
  return ReportUserUseCase(ref.watch(safetyRepositoryProvider));
});

/// Ids the current user has blocked — chat/discover screens filter
/// these out and disable messaging with them. `.autoDispose` matters
/// here specifically: a plain StreamProvider that hits a transient
/// PERMISSION_DENIED (e.g. right after sign-out, before Firestore's
/// auth context has finished propagating to a fresh sign-in) never
/// retries and stays stuck in that error state — reads as "Blokla"/
/// "Blokdan çıxart" permanently disagreeing with the real block state
/// — for the rest of the app session. `.autoDispose` lets it get torn
/// down and re-subscribed cleanly instead.
final blockedUserIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(safetyRepositoryProvider).watchBlockedUserIds(uid);
});
