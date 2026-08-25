import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/friendly_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../providers/safety_providers.dart';

/// Profile → Məxfilik və təhlükəsizlik. The only place a blocked user can
/// be unblocked once they've dropped out of Discover (blocked users are
/// filtered out there) and — if no chat thread exists with them — out of
/// every other screen in the app too.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final blockedAsync = ref.watch(blockedUserIdsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(loc.blockedUsersTitle),
      ),
      body: SafeArea(
        child: blockedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, st) => FriendlyErrorState(
            logContext: 'blocked_users_screen.blockedUserIdsProvider',
            error: e,
            stackTrace: st,
            onRetry: () => ref.invalidate(blockedUserIdsProvider),
          ),
          data: (blockedIds) {
            if (blockedIds.isEmpty) return _EmptyState(loc: loc);
            final ids = blockedIds.toList();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: ids.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) => _BlockedUserTile(uid: ids[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  final String uid;

  const _BlockedUserTile({required this.uid});

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  bool _unblocking = false;

  Future<void> _unblock() async {
    if (_unblocking) return;
    setState(() => _unblocking = true);

    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      await ref.read(unblockUserUseCaseProvider).call(myUid: myUid, blockedUid: widget.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatUserUnblockedNotice)));
      // No need to setState(_unblocking = false) on success — this uid
      // drops out of blockedUserIdsProvider and the tile is removed from
      // the list entirely by the parent's rebuild.
    } catch (e, st) {
      logError('blocked_users_screen.unblock', e, st);
      if (!mounted) return;
      setState(() => _unblocking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatRequestActionErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final peerAsync = ref.watch(publicProfileProvider(widget.uid));
    final peer = peerAsync.valueOrNull;
    final displayName = (peer?.name ?? '').isEmpty ? loc.defaultUserName : peer!.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.card,
            backgroundImage: peer?.photoUrl != null ? NetworkImage(peer!.photoUrl!) : null,
            child: peer?.photoUrl == null ? const Icon(Icons.person_outline, color: AppColors.textSecondary) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              displayName,
              style: AppTextStyles.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _unblocking ? null : _unblock,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _unblocking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Text(loc.chatMenuUnblock, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations loc;

  const _EmptyState({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
              child: const Icon(Icons.block_outlined, color: AppColors.textSecondary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(loc.blockedUsersEmptyTitle, style: AppTextStyles.cardTitle),
            const SizedBox(height: 10),
            Text(
              loc.blockedUsersEmptySubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
