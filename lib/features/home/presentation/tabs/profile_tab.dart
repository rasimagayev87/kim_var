import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app_config/domain/entities/app_config.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../discover_search/presentation/screens/discover_search_screen.dart';
import '../../../follow/presentation/providers/follow_providers.dart';
import '../../../follow/presentation/screens/follow_list_screen.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/presentation/providers/post_providers.dart';
import '../../../post_share/presentation/widgets/post_capture_sheet.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/providers/profile_visitors_providers.dart';
import '../../../profile/presentation/screens/profile_share_screen.dart';
import '../../../profile/presentation/screens/profile_visitors_screen.dart';
import '../../../profile/presentation/widgets/profile_display_widgets.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../stories/presentation/providers/story_providers.dart';
import '../../../stories/presentation/screens/create_story_screen.dart';
import '../../../stories/presentation/screens/story_viewer_screen.dart';

import '../../../../core/widgets/pressable.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final followingCount = myUid == null
        ? 0
        : ref.watch(followingCountProvider(myUid)).valueOrNull ?? 0;
    final followersCount = myUid == null
        ? 0
        : ref.watch(followersCountProvider(myUid)).valueOrNull ?? 0;
    final postsAsync = myUid == null
        ? const AsyncValue.data(<Post>[])
        : ref.watch(userPostsProvider(myUid));
    final likedPostsAsync = myUid == null
        ? const AsyncValue.data(<Post>[])
        : ref.watch(userLikedPostsProvider(myUid));
    final repostedPostsAsync = myUid == null
        ? const AsyncValue.data(<Post>[])
        : ref.watch(userRepostedPostsProvider(myUid));
    final newVisitorsCount = ref.watch(newProfileVisitorsCountProvider);

    final displayName = profile.name.isEmpty
        ? loc.profileNamePlaceholder
        : profile.name;

    return DefaultTabController(
          length: 3,
          // Plain fixed Column, not a NestedScrollView — the profile
          // header (avatar/name/stats) is never meant to scroll away;
          // only the media grid below the tab bar does, each tab
          // owning its own independent scroll.
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    // Unconstrained on phone (maxWidth simply never binds
                    // below 640 logical px); on tablet/landscape-wide
                    // layouts this keeps the header from stretching
                    // edge-to-edge into an unreadable single row of
                    // oversized avatars/text.
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (ref.watch(
                                featureFlagProvider(FeatureFlag.mediaUpload),
                              ))
                                IconButton(
                                  onPressed: () async {
                                    if (!context.mounted) return;
                                    startCreatePostFlow(context);
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: ChatLightColors.ink,
                                    size: 22,
                                  ),
                                ),
                              IconButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DiscoverSearchScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.search,
                                  color: ChatLightColors.ink,
                                  size: 22,
                                ),
                              ),
                              const Spacer(),
                              // Tightly grouped on purpose (no default
                              // IconButton spacing between them) — three
                              // buttons stretched across most of the row
                              // read as loose/unfinished, not premium.
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: myUid == null
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProfileVisitorsScreen(
                                                      uid: myUid,
                                                    ),
                                              ),
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.directions_walk,
                                      color: ChatLightColors.ink,
                                      size: 20,
                                    ),
                                  ),
                                  if (newVisitorsCount > 0)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 17,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: ChatLightColors.bg1,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            newVisitorsCount > 99
                                                ? '99+'
                                                : '$newVisitorsCount',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: (profile.username ?? '').isEmpty
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileShareScreen(
                                            name: displayName,
                                            username: profile.username!,
                                            photoUrl: profile.photoUrl,
                                          ),
                                        ),
                                      ),
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: ChatLightColors.ink,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.menu_rounded,
                                  color: ChatLightColors.ink,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          Center(
                            child: _AvatarWithRing(photoUrl: profile.photoUrl),
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
                                if (profile.identityVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_outlined,
                                    color: AppColors.primary,
                                    size: 21,
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
                            likes: myUid == null
                                ? 0
                                : ref.watch(userTotalPostLikesProvider(myUid)),
                            loc: loc,
                            onTapFollowing: myUid == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FollowListScreen(
                                        uid: myUid,
                                        initialTabIndex: 1,
                                      ),
                                    ),
                                  ),
                            onTapFollowers: myUid == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FollowListScreen(uid: myUid),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _ProfileMediaTabBar(),

              Expanded(
                child: TabBarView(
                  children: [
                    _ProfileMediaTabPage(
                      postsAsync: postsAsync,
                      logContext: 'profile_tab.userPostsProvider',
                    ),
                    _ProfileMediaTabPage(
                      postsAsync: likedPostsAsync,
                      logContext: 'profile_tab.userLikedPostsProvider',
                    ),
                    _ProfileMediaTabPage(
                      postsAsync: repostedPostsAsync,
                      logContext: 'profile_tab.userRepostedPostsProvider',
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 240.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut);
  }
}

/// One tab page of the media section below — resolves an
/// `AsyncValue<List<Post>>` (own/liked/reposted) into the loading/empty/
/// error/grid states, same fallback reasoning as the single-grid version
/// this replaced: a genuine stream failure (permission hiccup, transient
/// `unavailable`) is logged and shown as empty rather than left
/// indistinguishable from "truly zero posts". Always wrapped in a
/// scrollable (even the empty/loading states) since each page fills the
/// `Expanded` `TabBarView` area and owns its own scrolling — the header
/// above it (`ProfileTab`'s own `Column`) never scrolls at all.
class _ProfileMediaTabPage extends StatelessWidget {
  final AsyncValue<List<Post>> postsAsync;
  final String logContext;

  const _ProfileMediaTabPage({
    required this.postsAsync,
    required this.logContext,
  });

  @override
  Widget build(BuildContext context) {
    return postsAsync.when(
      data: (posts) => posts.isEmpty
          ? const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: PostFeedEmptyState(),
            )
          : PostGrid(posts: posts, scrollable: true),
      loading: () => const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: PostGridLoading(),
      ),
      error: (error, stackTrace) {
        logError(logContext, error, stackTrace);
        return const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: PostFeedEmptyState(),
        );
      },
    );
  }
}

/// Fixed icon-only tab bar between the profile header and the media
/// grid — own posts / liked / reposted, matching `PostGrid`'s own look
/// in every tab (see `_ProfileMediaTabPage`), so this only switches the
/// data source, never the grid's visual design. `dividerColor:
/// transparent` drops Material 3's default hairline under the tab bar,
/// which read as a stray leftover line against this app's own design.
class _ProfileMediaTabBar extends StatelessWidget {
  const _ProfileMediaTabBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ChatLightColors.bg1,
      child: TabBar(
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        unselectedLabelColor: ChatLightColors.inkFaint,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(CupertinoIcons.square_grid_2x2, size: 22)),
          Tab(icon: Icon(CupertinoIcons.heart, size: 23)),
          Tab(icon: Icon(CupertinoIcons.arrow_2_squarepath, size: 21)),
        ],
      ),
    );
  }
}

/// The gradient ring only appears while the signed-in user has at
/// least one non-expired story — tapping the photo then opens that
/// story (or stories, cycled in the viewer) instead of the gallery
/// picker. With no active story, tapping the photo starts the
/// create-story flow directly (editing the profile photo itself moved
/// to the hamburger menu, since this tap is now dedicated to stories).
/// The small "+" badge always opens the create-story flow regardless
/// of ring state, so another story can be added on top of an existing
/// active one.
class _AvatarWithRing extends ConsumerWidget {
  final String? photoUrl;

  const _AvatarWithRing({required this.photoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStories =
        ref.watch(myActiveStoriesProvider).valueOrNull ?? const [];
    final hasActiveStory = activeStories.isNotEmpty;
    final storiesEnabled = ref.watch(featureFlagProvider(FeatureFlag.stories));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Pressable(
          onTap: () async {
            if (hasActiveStory) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(stories: activeStories),
                ),
              );
              return;
            }
            if (!storiesEnabled || !context.mounted) return;
            startCreateStoryFlow(context);
          },
          child: Container(
            width: 128,
            height: 128,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // No active story: the ring "track" matches the page
              // background so it reads as no ring at all, rather than
              // changing the avatar's overall size when a story starts.
              // A thin gradient ring — same deliberate single-accent-hue
              // exception as `_ActiveStoryRing` on other users' profiles.
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Hero(
                  tag: 'own-profile-avatar',
                  child: photoUrl != null
                      ? AppImage(photoUrl!, fit: BoxFit.cover)
                      : const PhotoPlaceholderPattern(),
                ),
              ),
            ),
          ),
        ),
        if (storiesEnabled)
          Positioned(
            bottom: 2,
            right: 2,
            child: Pressable(
              onTap: () async {
                if (!context.mounted) return;
                startCreateStoryFlow(context);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: ChatLightColors.bg1, width: 3),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
