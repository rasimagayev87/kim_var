import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../providers/follow_providers.dart';
import 'follow_action_button.dart';

/// One row of a followers/following list — same shape everywhere
/// (avatar left, name+username stacked center, trailing action right;
/// tapping the avatar/name area — not the button — opens that user's
/// profile). Only the trailing action changes with context:
/// - [isOwnFollowersTab]: "Çıxart" — removes them from MY followers.
/// - [isOwnFollowingTab]: "Çıx" — I stop following them.
/// - neither (viewing someone else's list): the normal [FollowButton]
///   toggle, reflecting the SIGNED-IN user's own relationship to this
///   row's person — unrelated to whose list is being viewed.
class FollowListRow extends ConsumerWidget {
  final String uid;
  final bool isOwnFollowersTab;
  final bool isOwnFollowingTab;
  final VoidCallback onRemoved;

  const FollowListRow({
    super.key,
    required this.uid,
    required this.isOwnFollowersTab,
    required this.isOwnFollowingTab,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(publicProfileProvider(uid)).valueOrNull;
    final name = profile?.name ?? loc.defaultUserName;
    final photoUrl = profile?.photoUrl;

    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(uid: uid))),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ChatLightColors.cardSurface,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null ? const Icon(Icons.person_outline, color: ChatLightColors.inkSoft) : null,
      ),
      title: Text(name, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: (profile?.username ?? '').isEmpty
          ? null
          : Text('@${profile!.username}', style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 12.5)),
      trailing: SizedBox(
        width: 110,
        child: isOwnFollowersTab
            ? _RemoveActionButton(
                label: loc.followerRemoveButton,
                confirmMessage: loc.followerRemoveConfirmMessage,
                onConfirmed: () async {
                  final ok = await ref.read(followControllerProvider).removeFollower(uid);
                  if (ok) onRemoved();
                },
              )
            : isOwnFollowingTab
                ? _RemoveActionButton(
                    label: loc.unfollowButton,
                    confirmMessage: loc.unfollowConfirmMessage(name),
                    onConfirmed: () async {
                      final ok = await ref.read(followControllerProvider).toggleFollow(
                            otherUid: uid,
                            isCurrentlyFollowing: true,
                            isCurrentlyPending: false,
                            otherAccountIsPrivate: false,
                          );
                      if (ok) onRemoved();
                    },
                  )
                : FollowButton(otherUid: uid, displayName: name),
      ),
    );
  }
}

class _RemoveActionButton extends StatelessWidget {
  final String label;
  final String confirmMessage;
  final Future<void> Function() onConfirmed;

  const _RemoveActionButton({required this.label, required this.confirmMessage, required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(
      label: label,
      tonal: true,
      onPressed: () async {
        final loc = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            content: Text(confirmMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(label),
              ),
            ],
          ),
        );
        if (confirmed == true) await onConfirmed();
      },
    );
  }
}
