import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../privacy/domain/entities/privacy_settings.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../providers/follow_providers.dart';
import '../widgets/follow_list_row.dart';

/// Instagram-style "Kimlər izləyir / Kimi izləyir" screen — opened by
/// tapping the İzləyici/İzlənən counts on either `ProfileTab` (own
/// profile) or `UserProfileScreen` (someone else's). Same two tabs and
/// the same gate `_MediaVisibilityGate` already applies to a private
/// account's media/stories: `isOwn || accountPrivacy == public ||
/// isFollowing(viewer, uid)`.
class FollowListScreen extends ConsumerStatefulWidget {
  final String uid;
  final int initialTabIndex;

  const FollowListScreen({super.key, required this.uid, this.initialTabIndex = 0});

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwn = myUid != null && myUid == widget.uid;

    final privacy = isOwn ? const PrivacySettings() : ref.watch(otherUserPrivacySettingsProvider(widget.uid)).valueOrNull ?? const PrivacySettings();
    final isFollowing = isOwn ? true : ref.watch(isFollowingProvider(widget.uid)).valueOrNull ?? false;
    final canView = isOwn || privacy.accountPrivacy == AccountPrivacy.public || isFollowing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        bottom: canView
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: ChatLightColors.inkFaint,
                indicatorColor: AppColors.primary,
                tabs: [Tab(text: loc.followersTabTitle), Tab(text: loc.followingTabTitle)],
              )
            : null,
      ),
      body: SafeArea(
        child: canView
            ? TabBarView(
                controller: _tabController,
                children: [
                  _FollowListTab(uid: widget.uid, isFollowersTab: true, isOwnList: isOwn),
                  _FollowListTab(uid: widget.uid, isFollowersTab: false, isOwnList: isOwn),
                ],
              )
            : _PrivateAccountNotice(loc: loc),
      ),
    );
  }
}

class _PrivateAccountNotice extends StatelessWidget {
  final AppLocalizations loc;

  const _PrivateAccountNotice({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: ChatLightColors.inkFaint, size: 36),
            const SizedBox(height: 12),
            Text(
              loc.privacyClosedProfileNotice,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowListTab extends ConsumerStatefulWidget {
  final String uid;
  final bool isFollowersTab;
  final bool isOwnList;

  const _FollowListTab({required this.uid, required this.isFollowersTab, required this.isOwnList});

  @override
  ConsumerState<_FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends ConsumerState<_FollowListTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _notifier.loadMore();
    }
  }

  FollowListController get _notifier => widget.isFollowersTab
      ? ref.read(followersListControllerProvider(widget.uid).notifier)
      : ref.read(followingListControllerProvider(widget.uid).notifier);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final state = widget.isFollowersTab
        ? ref.watch(followersListControllerProvider(widget.uid))
        : ref.watch(followingListControllerProvider(widget.uid));

    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4));
    }

    if (state.hasError && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: ChatLightColors.inkFaint, size: 36),
              const SizedBox(height: 12),
              Text(
                loc.followErrorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isFollowersTab ? Icons.people_outline : Icons.person_add_alt_outlined,
                color: ChatLightColors.inkFaint,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isFollowersTab ? loc.followListEmptyFollowers : loc.followListEmptyFollowing,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1, color: ChatLightColors.cardSurface),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          );
        }
        final edge = state.items[index];
        return FollowListRow(
          uid: edge.uid,
          isOwnFollowersTab: widget.isOwnList && widget.isFollowersTab,
          isOwnFollowingTab: widget.isOwnList && !widget.isFollowersTab,
          onRemoved: () => _notifier.removeLocally(edge.uid),
        );
      },
    );
  }
}
