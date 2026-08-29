import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/private_data_ref.dart';
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

/// Ids of users who have blocked ME — the reverse of
/// [blockedUserIdsProvider]. `blockUser`/`unblockUser` only ever write
/// the BLOCKER's own `blockedUsers` array, so there's no way to answer
/// "who has blocked me" from that array alone; `onUserUpdated`
/// (functions/src/index.ts, Düzəliş Prompt 5) maintains this reverse
/// index on `users/{uid}/private/data.blockedByUsers` whenever anyone's
/// `blockedUsers` array changes.
final blockedByUsersProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return privateDataRef(uid).snapshots().map(
        (doc) => (doc.data()?['blockedByUsers'] as List?)?.cast<String>().toSet() ?? const <String>{},
      );
});

/// Every uid whose content should disappear from THIS user's own feeds
/// (posts/comments/stories — Düzəliş Prompt 5 / K-3) — the union of
/// "who I blocked" (I don't want to see them either) and "who blocked
/// me" (the spec's own explicit requirement: a blocked user must not
/// see the blocker's content anywhere, not just their profile page).
/// `firestore.rules` structurally can't filter these out of a LIST
/// query itself (same limitation as the `users` collection's own
/// list-query problem, Düzəliş Prompt 4 / RT-25) — every consumer of
/// this provider does the filtering client-side.
final hiddenAuthorIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final blockedByMe = ref.watch(blockedUserIdsProvider).valueOrNull ?? const <String>{};
  final blockedByOthers = ref.watch(blockedByUsersProvider).valueOrNull ?? const <String>{};
  return {...blockedByMe, ...blockedByOthers};
});
