import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../offers/presentation/providers/offer_providers.dart';
import '../widgets/live_feed_offer_card.dart';

/// "Hamısına bax" destination for Canlı's "Yaxınlıqdakı təkliflər" —
/// the same [nearbyOffersProvider] the carousel's last-3 is sliced
/// from, just shown in full here.
class LiveFeedAllOffersScreen extends ConsumerWidget {
  const LiveFeedAllOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final offersAsync = ref.watch(nearbyOffersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(loc.liveFeedSectionOffersNearby, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: offersAsync.when(
        data: (offers) => offers.isEmpty
            ? Center(child: Text(loc.offersEmptySubtitle, style: const TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => LiveFeedOfferCard(offer: offers[index].offer, distanceMeters: offers[index].distanceMeters),
              ),
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
        error: (_, _) => Center(child: Text(loc.offersEmptySubtitle, style: const TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }
}
