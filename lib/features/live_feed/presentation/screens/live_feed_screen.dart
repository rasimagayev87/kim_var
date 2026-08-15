import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/screens/event_details_screen.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../offers/presentation/screens/offer_details_screen.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../domain/entities/live_feed_item.dart';
import '../providers/live_feed_providers.dart';
import '../widgets/live_feed_card.dart';
import '../widgets/live_feed_ticker.dart';

/// "Canlı" — see `live_feed_providers.dart`'s doc comment for the full
/// "read-only aggregation, no new collection, fully deletable" design.
/// This screen owns [LiveFeedController]'s start/stop lifecycle: polling
/// runs only while this tab is the visible one AND the app is
/// foregrounded, per the explicit "arxa plana keçəndə dayandır"
/// requirement — [didChangeAppLifecycleState] plus [active] (mirroring
/// [FeedTab]'s own `active` flag convention for a tab living inside
/// [HomeScreen]'s `IndexedStack`) together cover both cases.
class LiveFeedScreen extends ConsumerStatefulWidget {
  final bool active;

  const LiveFeedScreen({super.key, this.active = false});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) ref.read(liveFeedControllerProvider.notifier).start();
  }

  @override
  void didUpdateWidget(covariant LiveFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      ref.read(liveFeedControllerProvider.notifier).start();
    } else if (!widget.active && oldWidget.active) {
      ref.read(liveFeedControllerProvider.notifier).stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;
    final controller = ref.read(liveFeedControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.active) ref.read(liveFeedControllerProvider.notifier).stop();
    super.dispose();
  }

  /// Awaitable so [LiveFeedTicker] can pause its scroll for the
  /// duration of the pushed screen and resume once it's popped.
  /// [LiveFeedType.audience] items never reach here — both
  /// [LiveFeedCard] and the ticker refuse to wire a tap for them.
  Future<void> _openItem(LiveFeedItem item) async {
    switch (item.targetType) {
      case 'venue':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => VenueProfileScreen(venueId: item.targetId)));
      case 'offer':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: item.targetId)));
      case 'event':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: item.targetId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final itemsAsync = ref.watch(liveFeedControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Text(
                    loc.liveFeedTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.white),
                  ),
                  const Spacer(),
                  const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                ],
              ),
            ),
            itemsAsync.when(
              data: (items) => LiveFeedTicker(items: items, onOpenItem: _openItem),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Expanded(
              child: itemsAsync.when(
                data: (items) => items.isEmpty ? const _LiveFeedEmptyState() : _LiveFeedList(items: items, onTap: _openItem),
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                error: (_, _) => const _LiveFeedEmptyState(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveFeedList extends StatelessWidget {
  final List<LiveFeedItem> items;
  final ValueChanged<LiveFeedItem> onTap;

  const _LiveFeedList({required this.items, required this.onTap});

  static const _sectionOrder = [
    LiveFeedType.audience,
    LiveFeedType.event,
    LiveFeedType.offer,
    LiveFeedType.seatAvailable,
    LiveFeedType.birthday,
  ];

  String _sectionTitle(AppLocalizations loc, LiveFeedType type) {
    return switch (type) {
      LiveFeedType.audience => loc.liveFeedSectionAudience,
      LiveFeedType.event => loc.liveFeedSectionEvent,
      LiveFeedType.offer => loc.liveFeedSectionOffer,
      LiveFeedType.seatAvailable => loc.liveFeedSectionSeatAvailable,
      LiveFeedType.birthday => loc.liveFeedSectionBirthday,
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final byType = <LiveFeedType, List<LiveFeedItem>>{};
    for (final item in items) {
      (byType[item.type] ??= []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final type in _sectionOrder)
          if (byType[type]?.isNotEmpty ?? false) ...[
            Text(
              _sectionTitle(loc, type),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.white),
            ),
            const SizedBox(height: 10),
            for (final item in byType[type]!) ...[
              LiveFeedCard(item: item, onTap: () => onTap(item)),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LiveFeedEmptyState extends ConsumerWidget {
  const _LiveFeedEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_outlined, color: AppColors.textMuted, size: 42),
            const SizedBox(height: 16),
            Text(
              loc.liveFeedEmptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _increaseRadius(ref),
              child: Text(loc.liveFeedIncreaseRadiusButton),
            ),
          ],
        ),
      ),
    );
  }

  /// Bumps the SAME radius state Kəşf et's own filter sheet writes to
  /// (`selectedDiscoverModeProvider`) — Canlı doesn't own a separate
  /// radius concept, it reuses Kəşf et's exactly as instructed, so
  /// widening it here is visible there too.
  void _increaseRadius(WidgetRef ref) {
    final current = ref.read(selectedDiscoverModeProvider);
    if (current.mode != DiscoverRadiusMode.distance || current.km == null) return;
    final next = (current.km! * 2).clamp(1.0, 100.0);
    ref.read(selectedDiscoverModeProvider.notifier).state = DiscoverRadiusSelection.distance(next);
  }
}
