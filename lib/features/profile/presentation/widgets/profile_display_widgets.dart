import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/presentation/screens/post_reel_viewer_screen.dart';

/// One shared implementation of the profile header's stats row, post
/// divider and media grid — used identically by `ProfileTab` (own
/// profile) and `UserProfileScreen` (someone else's), so a profile
/// looks and behaves the same regardless of where it's opened from.
/// Every explicit `fontWeight` here goes through `GoogleFonts.manrope`
/// directly (not a bare `TextStyle`) so that exact weight variant is
/// always fetched/cached correctly instead of silently falling back to
/// a substitute glyph for a weight nothing else in the app has loaded
/// yet.

/// Replaces the old "Dostlar"/"Bəyənilər" card pair — a single premium
/// inline row (Takip/Takipçi/Bəyənmə), no card background, no divider
/// box, just the three columns with thin vertical rules between them.
class ProfileStatsRow extends StatelessWidget {
  final int following;
  final int followers;
  final int likes;
  final AppLocalizations loc;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapFollowers;

  const ProfileStatsRow({
    super.key,
    required this.following,
    required this.followers,
    required this.likes,
    required this.loc,
    this.onTapFollowing,
    this.onTapFollowers,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              count: following,
              label: loc.profileStatsFollowing,
              onTap: onTapFollowing,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatColumn(
              count: followers,
              label: loc.profileStatsFollowers,
              onTap: onTapFollowers,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatColumn(count: likes, label: loc.profileStatsLikes),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: ChatLightColors.inkFaint.withValues(alpha: 0.25),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;

  const _StatColumn({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: count),
          duration: 420.ms,
          curve: Curves.easeOut,
          builder: (context, value, _) => Text(
            '$value',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ChatLightColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            color: ChatLightColors.inkSoft,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap == null) return column;
    // No padding here on purpose — this must render at EXACTLY the
    // same size as the non-tappable [likes] column beside it inside
    // `ProfileStatsRow`'s `IntrinsicHeight`, or the two would end up
    // different heights and throw the row's vertical centering off.
    return InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: column);
  }
}

/// Purely decorative separator between the stats row and the post
/// feed below it.
class PostsDivider extends StatelessWidget {
  const PostsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final lineColor = ChatLightColors.inkFaint.withValues(alpha: 0.3);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, lineColor]),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.perm_media_outlined,
            size: 16,
            color: ChatLightColors.inkSoft,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [lineColor, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Instagram/TikTok-style profile grid — 3 small square tiles per row,
/// tight gaps. Tapping any tile opens [PostReelViewerScreen] full-screen,
/// starting at that tile's post and swipeable through the rest of this
/// same list — the same experience as swiping through Lent, just scoped
/// to one profile's posts. Deliberately no video playback in the grid
/// itself (a plain icon badge instead) — initializing a
/// VideoPlayerController per grid tile would mean several decoding at
/// once while scrolling.
class PostGrid extends StatelessWidget {
  final List<Post> posts;

  /// False (default) for the existing usage — embedded, non-scrolling,
  /// inside an outer `ListView` that owns the scrolling. True for a
  /// grid that owns its own scrolling instead, e.g. one page of a
  /// `TabBarView` (see `profile_tab.dart`'s media tabs), which needs
  /// this `GridView` to actually scroll rather than try to take its
  /// unbounded natural height inside a bounded page.
  final bool scrollable;

  const PostGrid({super.key, required this.posts, this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: scrollable ? EdgeInsets.zero : null,
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, index) =>
          _PostGridTile(posts: posts, index: index),
    );
  }
}

class _PostGridTile extends StatelessWidget {
  final List<Post> posts;
  final int index;

  const _PostGridTile({required this.posts, required this.index});

  Post get post => posts[index];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostReelViewerScreen(posts: posts, initialIndex: index),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            // Videos have no directly-decodable mediaUrl here (it's the
            // .mp4 itself) — thumbnailUrl is the JPEG cover frame
            // generated at upload time. Falls back to the raw mediaUrl
            // only for posts shared before that field existed, which
            // then hits errorBuilder below like today. No `thumbnail:
            // true` here — a 3-up grid tile is ~130 logical px, which at
            // 3x device pixel ratio needs ~390 physical px; the
            // extension's 200x200 derivative would be visibly upscaled
            // and blurry at that size, so this loads the full-size
            // thumbnailUrl/mediaUrl directly instead.
            post.thumbnailUrl ?? post.mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
          ),
          if (post.mediaType == PostMediaType.video)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_arrow_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

class PostFeedEmptyState extends StatelessWidget {
  const PostFeedEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: ChatLightColors.inkFaint,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            loc.postFeedEmptyMessage,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: ChatLightColors.inkSoft,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for the media grid while its post stream is
/// still resolving — same spinner both screens used inline before.
class PostGridLoading extends StatelessWidget {
  const PostGridLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.4,
        ),
      ),
    );
  }
}
