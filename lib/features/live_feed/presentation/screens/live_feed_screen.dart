import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/screens/event_details_screen.dart';
import '../../../offers/presentation/screens/offer_details_screen.dart';
import '../../../pinbox/presentation/providers/pinbox_providers.dart';
import '../../../pinbox/presentation/screens/pinbox_checkout_screen.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../domain/entities/live_feed_item.dart';
import '../providers/live_feed_providers.dart';
import '../widgets/live_feed_events_section.dart';
import '../widgets/live_feed_hero_section.dart';
import '../widgets/live_feed_offers_section.dart';
import '../widgets/live_feed_pinbox_section.dart';
import '../widgets/live_feed_seats_section.dart';
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
      case 'pinbox':
        // No standalone PinBox details screen exists — Checkout doubles
        // as the detail view everywhere else PinBox is tapped from (see
        // `offer_list_view.dart`'s `_PinBoxCard`), so this fetches the
        // full entity once (unlike offer/event, which take a bare id)
        // and lands on the same screen.
        final pinbox = await ref.read(pinboxByIdProvider(item.targetId).future);
        if (!mounted || pinbox == null) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PinBoxCheckoutScreen(pinbox: pinbox)));
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
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    LiveFeedHeroSection(),
                    SizedBox(height: 24),
                    LiveFeedOffersSection(),
                    SizedBox(height: 24),
                    LiveFeedSeatsSection(),
                    SizedBox(height: 24),
                    LiveFeedPinboxSection(),
                    SizedBox(height: 24),
                    LiveFeedEventsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

