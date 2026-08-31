import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/screens/event_details_screen.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../../offers/presentation/screens/offer_details_screen.dart';
import '../../../pinbox/presentation/providers/pinbox_providers.dart';
import '../../../pinbox/presentation/screens/pinbox_checkout_screen.dart';
import '../../../premium/presentation/providers/premium_providers.dart';
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../../domain/entities/live_feed_item.dart';
import '../providers/live_feed_providers.dart';
import '../providers/birthday_feed_providers.dart';
import '../widgets/live_feed_birthday_section.dart';
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

  /// The exact same tiers Kəşf et's own picker offers
  /// (`kDefaultRadiusOptionsKm` + `kExtraRadiusOptionsKm`), plus
  /// Ölkə/Dünya for VIP users only — so cycling here can never land on
  /// a value that isn't a real, selectable option anywhere else in the
  /// app.
  List<DiscoverRadiusSelection> _radiusCycle(bool isPremium) => [
    for (final km in [...kDefaultRadiusOptionsKm, ...kExtraRadiusOptionsKm]) DiscoverRadiusSelection.distance(km),
    if (isPremium) const DiscoverRadiusSelection.country(),
    if (isPremium) const DiscoverRadiusSelection.world(),
  ];

  /// Updating that provider alone used to be silently invisible: the
  /// poll loop only picks up the new radius on its next scheduled tick
  /// (up to [liveFeedPollInterval] later), which read as "the button
  /// does nothing" — [LiveFeedController.refreshNow] forces an
  /// immediate fetch, and the snackbar confirms the tap registered
  /// even on the (likely, right after this radius still finds
  /// nothing) case where the list stays empty.
  void _increaseRadius(BuildContext context, WidgetRef ref) {
    final cycle = _radiusCycle(ref.read(isPremiumProvider));
    final currentIndex = cycle.indexOf(ref.read(selectedDiscoverModeProvider));
    final next = cycle[(currentIndex + 1) % cycle.length];
    ref.read(selectedDiscoverModeProvider.notifier).state = next;
    ref.read(liveFeedControllerProvider.notifier).refreshNow();

    final loc = AppLocalizations.of(context);
    final label = switch (next.mode) {
      DiscoverRadiusMode.distance =>
        next.km! < 1 ? '${(next.km! * 1000).round()} m' : '${next.km!.toStringAsFixed(0)} km',
      DiscoverRadiusMode.country => loc.privacyRadiusCountryLabel,
      DiscoverRadiusMode.world => loc.privacyRadiusWorldLabel,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.liveFeedRadiusIncreasedMessage(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final itemsAsync = ref.watch(liveFeedControllerProvider);
    // The birthday feed counts as content. Without this a user whose
    // birthday it is, but whose radius happens to hold nothing else,
    // would get the "nothing nearby, widen your radius" empty state on
    // the one day the server DID publish something specifically for
    // them — the campaigns are there, the screen just never gets to the
    // section that shows them.
    final hasBirthdayFeed = ref.watch(myBirthdayFeedProvider).valueOrNull?.isEmpty == false;
    final isEmpty = (itemsAsync.valueOrNull?.isEmpty ?? false) && !hasBirthdayFeed;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
              child: isEmpty
                  ? _LiveFeedEmptyState(onIncreaseRadius: () => _increaseRadius(context, ref))
                  : const SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16),
                          LiveFeedHeroSection(),
                          SizedBox(height: 24),
                          // Directly under the hero and above every
                          // other section: it appears one day a year,
                          // for one person, and renders nothing at all
                          // the rest of the time.
                          LiveFeedBirthdaySection(),
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

/// Shown instead of the section carousels when [LiveFeedController]'s
/// aggregate result is empty — the radius the user has selected simply
/// has nothing live in it yet, so the way out is to widen it, not to
/// stare at 5 empty sections one by one.
class _LiveFeedEmptyState extends StatelessWidget {
  final VoidCallback onIncreaseRadius;

  const _LiveFeedEmptyState({required this.onIncreaseRadius});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sensors_off_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              loc.liveFeedEmptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onIncreaseRadius,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text(loc.liveFeedIncreaseRadiusButton, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

