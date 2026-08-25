import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pinbox/presentation/providers/pinbox_providers.dart';
import '../widgets/live_feed_pinbox_card.dart';

/// "Hamısına bax" destination for Canlı's "PinBox elanları" — same
/// [nearbyPinBoxesProvider] the carousel's last-3 is sliced from,
/// sorted newest-first here too (the provider itself has no ordering
/// guarantee — see `live_feed_screen.dart`'s doc comment).
class LiveFeedAllPinboxesScreen extends ConsumerWidget {
  const LiveFeedAllPinboxesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pinboxesAsync = ref.watch(nearbyPinBoxesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(loc.liveFeedSectionPinboxListings, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: pinboxesAsync.when(
        data: (pinboxes) {
          // See `LiveFeedPinboxSection`'s own comment — the provider's
          // fetch can go stale relative to `pickupWindowEnd` the longer
          // it stays cached, so this re-checks against "now" on every
          // rebuild rather than trusting the fetch was recent.
          final active = pinboxes.where((r) => r.pinbox.pickupWindowEnd.isAfter(DateTime.now()));
          final sorted = [...active]..sort((a, b) => b.pinbox.createdAt.compareTo(a.pinbox.createdAt));
          return sorted.isEmpty
              ? Center(child: Text(loc.listingEmptyPinboxSubtitle, style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => LiveFeedPinboxCard(pinbox: sorted[index].pinbox, distanceMeters: sorted[index].distanceMeters),
                );
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
        error: (_, _) => Center(child: Text(loc.listingEmptyPinboxSubtitle, style: const TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }
}
