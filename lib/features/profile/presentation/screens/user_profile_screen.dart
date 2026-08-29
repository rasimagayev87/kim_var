import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_conversation_screen.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../follow/presentation/providers/follow_providers.dart';
import '../../../follow/presentation/screens/follow_list_screen.dart';
import '../../../follow/presentation/widgets/follow_action_button.dart';
import '../../../home/presentation/tabs/profile_tab.dart';
import '../../domain/entities/public_profile.dart';
import '../../../location/presentation/providers/presence_provider.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../../../safety/presentation/providers/safety_providers.dart';
import '../../../safety/presentation/widgets/report_user_sheet.dart';
import '../widgets/verification_badges.dart';
import '../../../stories/domain/entities/story.dart';
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
    ref.watch(presenceTickProvider); // forces re-evaluation of isRecentlyActive as time passes

    final profileAsync = ref.watch(publicProfileProvider(uid));

    // Düzəliş Prompt 5 (K-3) — `.valueOrNull` alone can't tell "still
    // loading" apart from "genuinely absent" (both read as `null`),
    // which is exactly what's needed here: a blocked profile (denied by
    // `firestore.rules`) and a deleted/nonexistent one must show the
    // SAME "Hesab tapılmadı" screen, with no menu/stats/grid rendered
    // at all — never a half-populated shell with a working Block/Report
    // menu for an account that, from this viewer's side, doesn't exist.
    return profileAsync.when(
      loading: () => const _ProfileLoadingScaffold(),
      error: (_, _) => const _ProfileNotFoundScaffold(),
      data: (profile) {
        if (profile == null) return const _ProfileNotFoundScaffold();
        return _OtherProfileBody(
          uid: uid,
          profile: profile,
          initialName: initialName,
          initialPhotoUrl: initialPhotoUrl,
          chatId: chatId,
        );
      },
    );
  }
}

class _ProfileLoadingScaffold extends StatelessWidget {
  const _ProfileLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
            ),
          ),
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// Shown for a blocked profile AND a genuinely deleted/nonexistent one
/// — deliberately indistinguishable (see `UserProfileScreen.build`'s
/// own doc comment). No menu, no stats, no media grid: there is nothing
/// here for this viewer to interact with either way.
class _ProfileNotFoundScaffold extends StatelessWidget {
  const _ProfileNotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_outlined, color: ChatLightColors.inkFaint, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    loc.profileNotFoundTitle,
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full "someone else's profile" layout — only ever built once
/// [PublicProfile] has actually resolved, so nothing here needs a null
/// check on `profile` itself (unlike the old combined build method).
class _OtherProfileBody extends ConsumerWidget {
  final String uid;
  final PublicProfile profile;
  final String? initialName;
  final String? initialPhotoUrl;
  final String? chatId;

  const _OtherProfileBody({
    required this.uid,
    required this.profile,
    required this.initialName,
    required this.initialPhotoUrl,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final displayName = profile.name.isEmpty ? (initialName?.isNotEmpty == true ? initialName! : loc.defaultUserName) : profile.name;
    final photoUrl = profile.photoUrl ?? initialPhotoUrl;

    final followingCount = ref.watch(followingCountProvider(uid)).valueOrNull ?? 0;
    final followersCount = ref.watch(followersCountProvider(uid)).valueOrNull ?? 0;
    final likesCount = ref.watch(userTotalPostLikesProvider(uid));

    return Stack(
          children: [
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
                        child: _OtherAvatarWithRing(
                          uid: uid,
                          photoUrl: photoUrl,
                          isPrivate: (ref.watch(otherUserPrivacySettingsProvider(uid)).valueOrNull ?? const PrivacySettings())
                                  .accountPrivacy ==
                              AccountPrivacy.private,
                        ),
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
                            if (profile.identityVerified || profile.premium) ...[
                              const SizedBox(width: 6),
                              VerificationBadges(identityVerified: profile.identityVerified, premium: profile.premium),
                            ],
                            if (profile.isRecentlyActive) ...[
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
                      if ((profile.username ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Center(
                          child: Text(
                            '@${profile.username}',
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
                        onTapFollowing: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid, initialTabIndex: 1)),
                        ),
                        onTapFollowers: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileActionRow(
                        otherUid: uid,
                        displayName: displayName,
                        photoUrl: photoUrl,
                      ),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(profile.bio, style: const TextStyle(fontSize: 14.5, height: 1.5, color: ChatLightColors.ink)),
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
///
/// Tap/long-press behavior depends entirely on [isPrivate] ("Hesab
/// gizliliyi"): a `public` account's avatar is always interactive
/// (single tap opens the active story if there is one, otherwise
/// zooms the photo; long-press always offers both options, "Statusuna
/// bax" grayed out when there's no story to watch) — a `private`
/// account's avatar does nothing at all on either gesture, for anyone
/// but the owner, regardless of follow status. This is a literal
/// reading of the "Hesab gizliliyi" spec, which enumerates the avatar
/// as fully inert for a private account without carving out an
/// accepted-follower exception the way it does for the media grid.
class _OtherAvatarWithRing extends ConsumerWidget {
  final String uid;
  final String? photoUrl;
  final bool isPrivate;

  const _OtherAvatarWithRing({required this.uid, required this.photoUrl, required this.isPrivate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Story> activeStories =
        isPrivate ? const [] : ref.watch(activeStoriesForUserProvider(uid)).valueOrNull ?? const [];
    final hasActiveStory = activeStories.isNotEmpty;
    final heroTag = 'user-profile-avatar-$uid';

    return GestureDetector(
      onTap: isPrivate
          ? null
          : () async {
              if (hasActiveStory) {
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: activeStories)));
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ZoomedAvatarScreen(photoUrl: photoUrl, heroTag: heroTag),
                    fullscreenDialog: true,
                  ),
                );
              }
            },
      onLongPress: isPrivate
          ? null
          : () => _showAvatarMenu(
                context,
                ref,
                uid: uid,
                photoUrl: photoUrl,
                heroTag: heroTag,
                hasActiveStory: hasActiveStory,
                activeStories: activeStories,
              ),
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
              tag: heroTag,
              child: photoUrl != null
                  ? AppImage(photoUrl!, fit: BoxFit.cover)
                  : const PhotoPlaceholderPattern(),
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarMenu(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String? photoUrl,
    required String heroTag,
    required bool hasActiveStory,
    required List<Story> activeStories,
  }) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_outline, color: ChatLightColors.ink),
                title: Text(loc.avatarMenuViewPhoto, style: const TextStyle(color: ChatLightColors.ink, fontSize: 15)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ZoomedAvatarScreen(photoUrl: photoUrl, heroTag: heroTag),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              ListTile(
                enabled: hasActiveStory,
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: hasActiveStory ? ChatLightColors.ink : ChatLightColors.inkFaint,
                ),
                title: Text(
                  loc.avatarMenuViewStatus,
                  style: TextStyle(color: hasActiveStory ? ChatLightColors.ink : ChatLightColors.inkFaint, fontSize: 15),
                ),
                onTap: hasActiveStory
                    ? () async {
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: activeStories)),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen, tap-to-dismiss circular zoom of a profile photo —
/// shares [heroTag] with the small ring avatar it was opened from so
/// the transition is a smooth expand/collapse rather than a hard cut.
class _ZoomedAvatarScreen extends StatelessWidget {
  final String? photoUrl;
  final String heroTag;

  const _ZoomedAvatarScreen({required this.photoUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Hero(
            tag: heroTag,
            child: ClipOval(
              child: SizedBox(
                width: 280,
                height: 280,
                child: photoUrl != null
                    ? AppImage(photoUrl!, fit: BoxFit.cover)
                    : const ColoredBox(color: Colors.white, child: PhotoPlaceholderPattern()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decides whether the signed-in user is allowed to see [uid]'s media
/// grid, per [AccountPrivacy]: `public` always shows it; `private`
/// requires the SIGNED-IN user to hold an ACCEPTED follow edge
/// pointing AT [uid] specifically (one direction only — [uid] having
/// followed the viewer back doesn't count, matching a real request/
/// approve relationship rather than the old either-direction
/// heuristic). Ghost Mode is deliberately NOT consulted here — it only
/// ever hides [uid] from the map/Discover, never their profile or
/// media.
class _MediaVisibilityGate extends ConsumerWidget {
  final String uid;

  const _MediaVisibilityGate({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final privacy = ref.watch(otherUserPrivacySettingsProvider(uid)).valueOrNull ?? const PrivacySettings();
    final isFollowing = ref.watch(isFollowingProvider(uid)).valueOrNull ?? false;

    final canView = privacy.accountPrivacy == AccountPrivacy.public || isFollowing;

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

/// The Follow/Message action row — becomes Accept/Decline (plus
/// Message, still always present per spec) instead of Follow whenever
/// [otherUid] has sent the SIGNED-IN user a still-pending request:
/// this is exactly the profile a `followRequest` notification's tap
/// deep-links to, so approving/declining happens right here rather
/// than on some separate, unbuilt "requests" screen.
class _ProfileActionRow extends ConsumerWidget {
  final String otherUid;
  final String displayName;
  final String? photoUrl;

  const _ProfileActionRow({required this.otherUid, required this.displayName, required this.photoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final incomingRequest = ref.watch(incomingFollowRequestProvider(otherUid)).valueOrNull ?? false;

    final messageButton = Expanded(
      child: ProfileActionButton(
        label: loc.sendMessageButton,
        tonal: true,
        onPressed: () async {
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(otherUid: otherUid, otherName: displayName, otherPhotoUrl: photoUrl),
            ),
          );
        },
      ),
    );

    if (incomingRequest) {
      return Row(
        children: [
          Expanded(
            child: ProfileActionButton(
              label: loc.followRequestAcceptButton,
              tonal: false,
              onPressed: () async {
                final ok = await ref.read(followControllerProvider).acceptFollowRequest(otherUid);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.followErrorMessage)));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ProfileActionButton(
              label: loc.followRequestDeclineButton,
              tonal: true,
              onPressed: () async {
                final ok = await ref.read(followControllerProvider).declineFollowRequest(otherUid);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.followErrorMessage)));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          messageButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: FollowButton(otherUid: otherUid, displayName: displayName)),
        const SizedBox(width: 10),
        messageButton,
      ],
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
