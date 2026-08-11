import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../../domain/entities/post.dart';
import '../widgets/post_owner_menu_button.dart';
import '../widgets/post_reel_item.dart';

/// Full-screen, swipe-through-vertically viewer over a list of posts —
/// the same [PostReelItem] Lent (the "Lent" tab) uses, just fed a
/// user's own post list instead of the cross-user feed. Pushed from a
/// profile grid tile tap: the tapped post plays immediately at
/// [initialIndex], and swiping up/down moves through that same
/// profile's other posts in order, exactly like Lent — no separate
/// "tap once to see a thumbnail, tap again to play" detail page.
class PostReelViewerScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const PostReelViewerScreen({super.key, required this.posts, required this.initialIndex});

  @override
  State<PostReelViewerScreen> createState() => _PostReelViewerScreenState();
}

class _PostReelViewerScreenState extends State<PostReelViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentPage = widget.initialIndex;
  bool _muted = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPost = widget.posts[_currentPage];
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = myUid != null && currentPost.userId == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => PostReelItem(
              post: widget.posts[index],
              isCurrent: index == _currentPage,
              muted: _muted,
            ),
          ),
          _ReelViewerTopBar(
            onBack: () => Navigator.pop(context),
            muted: _muted,
            onToggleMute: () => setState(() => _muted = !_muted),
            showMuteButton: currentPost.mediaType == PostMediaType.video,
            ownerMenu: isOwner ? PostOwnerMenuButton(post: currentPost) : null,
          ),
        ],
      ),
    );
  }
}

class _ReelViewerTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool showMuteButton;
  final Widget? ownerMenu;

  const _ReelViewerTopBar({
    required this.onBack,
    required this.muted,
    required this.onToggleMute,
    required this.showMuteButton,
    required this.ownerMenu,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            const Spacer(),
            if (showMuteButton) MuteToggleButton(muted: muted, onTap: onToggleMute),
            if (ownerMenu != null) ...[
              const SizedBox(width: 4),
              ownerMenu!,
            ],
          ],
        ),
      ),
    );
  }
}
