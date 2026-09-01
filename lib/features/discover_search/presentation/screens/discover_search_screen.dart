import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/photo_placeholder_pattern.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../post_share/domain/entities/post.dart';
import '../../../post_share/presentation/screens/post_reel_viewer_screen.dart';
import '../../../profile/domain/entities/public_profile.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../providers/discover_search_providers.dart';
import '../providers/public_video_feed_providers.dart';

import '../../../../core/widgets/pressable.dart';

/// Opened from the search icon next to "+" on the Profile tab. A
/// search bar over a default (empty-query) 3-column grid of newest
/// public-account videos — typing swaps the grid for live search
/// results across users (@username first, then name) and venues.
class DiscoverSearchScreen extends ConsumerStatefulWidget {
  const DiscoverSearchScreen({super.key});

  @override
  ConsumerState<DiscoverSearchScreen> createState() =>
      _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends ConsumerState<DiscoverSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(publicVideoFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final searchState = ref.watch(discoverSearchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: ChatLightColors.ink,
                    ),
                  ),
                  Expanded(
                    child: _SearchField(
                      controller: _searchController,
                      hintText: loc.discoverSearchHint,
                      onChanged: (value) => ref
                          .read(discoverSearchControllerProvider.notifier)
                          .onQueryChanged(value),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: searchState.hasQuery
                  ? _SearchResultsList(state: searchState, loc: loc)
                  : _PublicVideoGrid(
                      scrollController: _scrollController,
                      loc: loc,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: ChatLightColors.inkFaint,
            fontSize: 14.5,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: ChatLightColors.inkFaint,
            size: 21,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: ChatLightColors.inkFaint,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final DiscoverSearchState state;
  final AppLocalizations loc;

  const _SearchResultsList({required this.state, required this.loc});

  @override
  Widget build(BuildContext context) {
    if (!state.isSearching && state.users.isEmpty && state.venues.isEmpty) {
      return Center(
        child: Text(
          loc.discoverSearchNoResultsMessage,
          style: const TextStyle(color: ChatLightColors.inkFaint),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (state.users.isNotEmpty) ...[
          _SectionHeader(loc.discoverSearchUsersSection),
          for (final user in state.users) _UserResultRow(user: user),
        ],
        if (state.venues.isNotEmpty) ...[
          _SectionHeader(loc.discoverSearchVenuesSection),
          for (final venue in state.venues) _VenueResultRow(venue: venue),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: ChatLightColors.inkFaint,
        ),
      ),
    );
  }
}

class _UserResultRow extends StatelessWidget {
  final PublicProfile user;

  const _UserResultRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(uid: user.id)),
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ChatLightColors.cardSurface,
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? const Icon(Icons.person_outline, color: ChatLightColors.inkSoft)
            : null,
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          color: ChatLightColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: (user.username ?? '').isEmpty
          ? null
          : Text(
              '@${user.username}',
              style: const TextStyle(
                color: ChatLightColors.inkFaint,
                fontSize: 12.5,
              ),
            ),
    );
  }
}

class _VenueResultRow extends StatelessWidget {
  final Venue venue;

  const _VenueResultRow({required this.venue});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VenueProfileScreen(venueId: venue.id),
        ),
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ChatLightColors.cardSurface,
        backgroundImage: venue.photoUrl != null
            ? NetworkImage(venue.photoUrl!)
            : null,
        child: venue.photoUrl == null
            ? const Icon(
                Icons.storefront_outlined,
                color: ChatLightColors.inkSoft,
              )
            : null,
      ),
      title: Text(
        venue.name,
        style: const TextStyle(
          color: ChatLightColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        venue.address,
        style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 12.5),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PublicVideoGrid extends ConsumerWidget {
  final ScrollController scrollController;
  final AppLocalizations loc;

  const _PublicVideoGrid({required this.scrollController, required this.loc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visiblePublicVideoFeedProvider);

    if (state.isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
        ),
      );
    }

    if (state.videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            loc.discoverVideoFeedEmptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ChatLightColors.inkFaint),
          ),
        ),
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: state.videos.length + (state.isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= state.videos.length) {
          return const ColoredBox(color: ChatLightColors.cardSurface);
        }
        return _VideoGridTile(videos: state.videos, index: index);
      },
    );
  }
}

/// Grid tiles preview like Instagram/TikTok's do: once >60% on-screen,
/// a muted, silently-initialized player starts looping just the first
/// [_kPreviewWindow] of the clip (not the whole thing — seeking back
/// to zero itself once it reaches that point, rather than relying on
/// `looping: true`, which would loop the entire video). Tiles that
/// scroll off-screen dispose their controller immediately — `GridView.
/// builder`'s own lazy building already bounds how many tiles exist as
/// widgets at once, so this never has more concurrent decoders running
/// than roughly a couple of screens' worth.
class _VideoGridTile extends StatefulWidget {
  final List<Post> videos;
  final int index;

  const _VideoGridTile({required this.videos, required this.index});

  @override
  State<_VideoGridTile> createState() => _VideoGridTileState();
}

const _kPreviewWindow = Duration(seconds: 6);

class _VideoGridTileState extends State<_VideoGridTile> {
  Post get _post => widget.videos[widget.index];

  VideoPlayerController? _controller;
  bool _startingOrPlaying = false;

  @override
  void dispose() {
    _controller?.removeListener(_loopWithinPreviewWindow);
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.6;
    if (visible && !_startingOrPlaying) {
      _startPreview();
    } else if (!visible && _startingOrPlaying) {
      _stopPreview();
    }
  }

  Future<void> _startPreview() async {
    _startingOrPlaying = true;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_post.mediaUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      // The tile may have scrolled away (or been disposed) while
      // `initialize` was in flight — `_controller` no longer being
      // THIS controller means a newer call already superseded it.
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(0);
      controller.addListener(_loopWithinPreviewWindow);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Best-effort — the static thumbnail underneath is still shown.
      if (_controller == controller) _controller = null;
    }
  }

  void _loopWithinPreviewWindow() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.position >= _kPreviewWindow) {
      controller.seekTo(Duration.zero);
    }
  }

  void _stopPreview() {
    _startingOrPlaying = false;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_loopWithinPreviewWindow);
    controller?.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo = controller != null && controller.value.isInitialized;

    return VisibilityDetector(
      key: ValueKey('discover_video_tile_${_post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Pressable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostReelViewerScreen(
              posts: widget.videos,
              initialIndex: widget.index,
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(
              _post.thumbnailUrl ?? _post.mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const PhotoPlaceholderPattern(),
            ),
            if (showVideo)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
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
      ),
    );
  }
}
