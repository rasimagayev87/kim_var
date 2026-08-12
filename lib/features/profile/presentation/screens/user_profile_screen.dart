import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_conversation_screen.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../follow/presentation/providers/follow_providers.dart';
import '../../../home/presentation/tabs/profile_tab.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../safety/presentation/providers/safety_providers.dart';
import '../../../safety/presentation/widgets/report_user_sheet.dart';
import '../../../stories/presentation/providers/story_providers.dart';
import '../../../stories/presentation/screens/story_viewer_screen.dart';
import '../providers/profile_visitors_providers.dart';
import '../providers/public_profile_providers.dart';
import '../widgets/profile_display_widgets.dart';

/// The ONE way to view a profile, no matter where the tap came from
/// (map card, chat header, Lent post author, another profile's story
/// ring) — a single consistent rule instead of several near-identical
/// hand-rolled layouts that used to drift apart:
///
/// - [uid] is the SIGNED-IN user's own → shows exactly `ProfileTab`'s
///   own-profile UI (same widget, not a lookalike), just with a back
///   button added since this route isn't the bottom-nav tab. No
///   Follow/Message buttons — messaging yourself was never a real
///   feature, it was a symptom of not doing this redirect.
/// - Otherwise → the "someone else" layout below. Always the same
///   regardless of [chatId]: Follow AND Message both always show
///   (opening the message button while already inside that chat just
///   re-navigates to it, which is harmless — hiding it depending on
///   entry point was the actual inconsistency being fixed here).
///
/// The top-right "..." menu always offers Block/Report; Delete chat is
/// added to that same menu only when [chatId] is set (i.e. this was
/// opened from an active chat) — that's the one legitimate case where
/// the entry point should still matter.
class UserProfileScreen extends ConsumerWidget {
  final String uid;
  final String? initialName;
  final String? initialPhotoUrl;
  final String? chatId;

  const UserProfileScreen({
    super.key,
    required this.uid,
    this.initialName,
    this.initialPhotoUrl,
    this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && myUid == uid) {
      return const _OwnProfileRoute();
    }

    // Fire-and-forget "you viewed this profile" record — an
    // autoDispose.family FutureProvider so it fires once per fresh
    // navigation into this screen (see profile_visitors_providers.dart)
    // rather than needing an initState this ConsumerWidget doesn't have.
    ref.watch(recordProfileVisitProvider(uid));

    final loc = AppLocalizations.of(context);
    final profileAsync = ref.watch(publicProfileProvider(uid));
    final profile = profileAsync.valueOrNull;

    final displayName = (profile?.name ?? initialName ?? '').isEmpty
        ? loc.defaultUserName
        : (profile?.name ?? initialName)!;
    final photoUrl = profile?.photoUrl ?? initialPhotoUrl;

    final followingCount = ref.watch(followingCountProvider(uid)).valueOrNull ?? 0;
    final followersCount = ref.watch(followersCountProvider(uid)).valueOrNull ?? 0;
    final likesCount = ref.watch(userTotalPostLikesProvider(uid));

    return Stack(
          children: [
            const ChatLightBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
                          ),
                          const Spacer(),
                          _ProfileMenuButton(uid: uid, chatId: chatId),
                        ],
                      ),
                      Center(
                        child: _OtherAvatarWithRing(uid: uid, photoUrl: photoUrl),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: GoogleFonts.manrope(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: ChatLightColors.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (profile?.isRecentlyActive == true) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if ((profile?.username ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Center(
                          child: Text(
                            '@${profile!.username}',
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              color: ChatLightColors.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ProfileStatsRow(
                        following: followingCount,
                        followers: followersCount,
                        likes: likesCount,
                        loc: loc,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _FollowButton(otherUid: uid)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileActionButton(
                              label: loc.sendMessageButton,
                              tonal: true,
                              onPressed: () async {
                                if (!await requireVerified(context, ref)) return;
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(
                                      otherUid: uid,
                                      otherName: displayName,
                                      otherPhotoUrl: photoUrl,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      if ((profile?.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(profile!.bio, style: const TextStyle(fontSize: 14.5, height: 1.5, color: ChatLightColors.ink)),
                      ],
                      const SizedBox(height: 20),
                      const PostsDivider(),
                      const SizedBox(height: 14),
                      _MediaVisibilityGate(uid: uid),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 240.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut);
  }
}

/// Renders exactly `ProfileTab` — the signed-in user's own profile,
/// reached from anywhere other than the bottom-nav Profile tab itself
/// (Lent post avatar, a chat header, a map card) — with a floating
/// back button added since this route isn't the tab (which relies on
/// bottom nav instead of a back affordance). Positioned clear of
/// `ProfileTab`'s own top-right icon row.
class _OwnProfileRoute extends StatelessWidget {
  const _OwnProfileRoute();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ProfileTab(),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

/// Same ring treatment as `ProfileTab`'s own avatar, minus the "+"
/// badge and create-story affordance — viewing someone else's profile
/// only ever lets you WATCH their active story, never start one.
class _OtherAvatarWithRing extends ConsumerWidget {
  final String uid;
  final String? photoUrl;

  const _OtherAvatarWithRing({required this.uid, required this.photoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStories = ref.watch(activeStoriesForUserProvider(uid)).valueOrNull ?? const [];
    final hasActiveStory = activeStories.isNotEmpty;

    return GestureDetector(
      onTap: hasActiveStory
          ? () async {
              if (!await requireVerified(context, ref)) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: activeStories)),
              );
            }
          : null,
      child: Container(
        width: 128,
        height: 128,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasActiveStory
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF7DEEE0)],
                )
              : null,
          color: hasActiveStory ? null : ChatLightColors.bg1,
        ),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: ClipOval(
            child: Hero(
              tag: 'user-profile-avatar-$uid',
              child: photoUrl != null ? Image.network(photoUrl!, fit: BoxFit.cover) : const PhotoPlaceholderPattern(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decides whether the signed-in user is allowed to see [uid]'s media
/// grid, per [ProfileVisibility]: `everyone` always shows it, `noOne`
/// never does, `followersOnly` requires an either-direction follow
/// relationship (see `isFollowedByProvider`'s doc comment). Ghost Mode
/// is deliberately NOT consulted here — it only ever hides [uid] from
/// the map/Discover, never their profile or media.
class _MediaVisibilityGate extends ConsumerWidget {
  final String uid;

  const _MediaVisibilityGate({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final privacy = ref.watch(otherUserPrivacySettingsProvider(uid)).valueOrNull ?? const PrivacySettings();
    final isFollowing = ref.watch(isFollowingProvider(uid)).valueOrNull ?? false;
    final isFollowedBy = ref.watch(isFollowedByProvider(uid)).valueOrNull ?? false;

    final canView = switch (privacy.profileVisibility) {
      ProfileVisibility.everyone => true,
      ProfileVisibility.followersOnly => isFollowing || isFollowedBy,
      ProfileVisibility.noOne => false,
    };

    if (!canView) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, color: ChatLightColors.inkFaint, size: 36),
            const SizedBox(height: 12),
            Text(
              loc.privacyClosedProfileNotice,
              style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final postsAsync = ref.watch(userPostsProvider(uid));
    return postsAsync.when(
      data: (posts) => posts.isEmpty ? const PostFeedEmptyState() : PostGrid(posts: posts),
      loading: () => const PostGridLoading(),
      error: (_, _) => const PostFeedEmptyState(),
    );
  }
}

/// One-directional follow — needs no acceptance from [otherUid],
/// toggles instantly on tap. Filled app-accent while not following;
/// once followed, fades to the same pale tonal look as the "Mesaj yaz"
/// button next to it (see [_ProfileActionButton]).
class _FollowButton extends ConsumerWidget {
  final String otherUid;

  const _FollowButton({required this.otherUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    final isFollowing = ref.watch(isFollowingProvider(otherUid)).valueOrNull ?? false;

    return _ProfileActionButton(
      label: isFollowing ? loc.followingButton : loc.followButton,
      tonal: isFollowing,
      onPressed: () async {
        if (!await requireVerified(context, ref)) return;
        if (!context.mounted) return;
        final success = await ref
            .read(followControllerProvider)
            .toggleFollow(otherUid: otherUid, isCurrentlyFollowing: isFollowing);
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.followErrorMessage)));
        }
      },
    );
  }
}

/// Thin, minimal (no icon) pill button for the Takip et/Mesaj yaz pair
/// — `tonal: false` is the solid app-accent fill (Takip et before
/// following); `tonal: true` is the same pale accent-tinted wash used
/// for Mesaj yaz and for Takip et once already following.
class _ProfileActionButton extends StatelessWidget {
  final String label;
  final bool tonal;
  final VoidCallback? onPressed;

  const _ProfileActionButton({required this.label, required this.tonal, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final background = tonal ? AppColors.primary.withValues(alpha: 0.12) : AppColors.primary;
    final foreground = tonal ? AppColors.primary : AppColors.onAccent;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground),
          ),
        ),
      ),
    );
  }
}

enum _ProfileMenuAction { block, report, deleteChat }

/// Top-right "..." menu on any other user's profile — always offers
/// Block/Report; adds Delete chat only when this profile was reached
/// from an active chat (i.e. [chatId] is set).
class _ProfileMenuButton extends ConsumerWidget {
  final String uid;
  final String? chatId;

  const _ProfileMenuButton({required this.uid, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final blockedIds = ref.watch(blockedUserIdsProvider).valueOrNull ?? const <String>{};
    final isBlocked = blockedIds.contains(uid);

    return PopupMenuButton<_ProfileMenuAction>(
      icon: const Icon(Icons.more_vert, color: ChatLightColors.ink),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (action) {
        switch (action) {
          case _ProfileMenuAction.block:
            _handleBlockToggle(context, ref, isBlocked: isBlocked);
            break;
          case _ProfileMenuAction.report:
            showReportUserSheet(context, ref, reportedId: uid, chatId: chatId);
            break;
          case _ProfileMenuAction.deleteChat:
            _confirmDeleteChat(context, ref);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ProfileMenuAction.block,
          child: _MenuEntry(
            icon: isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
            label: isBlocked ? loc.chatMenuUnblock : loc.chatMenuBlock,
            // Unblocking is a benign "undo", not a destructive action —
            // reads as a normal row instead of the red block/report ones.
            color: isBlocked ? ChatLightColors.ink : AppColors.error,
          ),
        ),
        PopupMenuItem(
          value: _ProfileMenuAction.report,
          child: _MenuEntry(icon: Icons.flag_outlined, label: loc.chatMenuReport),
        ),
        if (chatId != null)
          PopupMenuItem(
            value: _ProfileMenuAction.deleteChat,
            child: _MenuEntry(icon: Icons.delete_outline, label: loc.chatMenuDeleteChat),
          ),
      ],
    );
  }

  Future<void> _handleBlockToggle(BuildContext context, WidgetRef ref, {required bool isBlocked}) async {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    if (isBlocked) {
      try {
        await ref.read(unblockUserUseCaseProvider).call(myUid: myUid, blockedUid: uid);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatUserUnblockedNotice)));
      } catch (e, st) {
        logError('user_profile_screen.unblock', e, st);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatRequestActionErrorMessage)));
      }
      return;
    }

    final confirmed = await _confirmDialog(
      context,
      title: loc.chatBlockConfirmTitle,
      message: loc.chatBlockConfirmMessage,
      confirmLabel: loc.chatMenuBlock,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(blockUserUseCaseProvider).call(myUid: myUid, blockedUid: uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatUserBlockedNotice)));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e, st) {
      logError('user_profile_screen.block', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.chatRequestActionErrorMessage)));
    }
  }

  Future<void> _confirmDeleteChat(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await _confirmDialog(
      context,
      title: loc.chatDeleteConfirmTitle,
      message: loc.chatDeleteConfirmMessage,
      confirmLabel: loc.actionDelete,
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(chatControllerProvider.notifier).deleteChat(chatId!);
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final loc = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(message, style: const TextStyle(color: ChatLightColors.inkSoft, fontSize: 14.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuEntry({required this.icon, required this.label, this.color = AppColors.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
