import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/pinbox.dart';
import '../../domain/entities/pinbox_order.dart';
import '../providers/pinbox_providers.dart';
import 'pinbox_ticket_screen.dart';

/// PinBox Faza 11 — replaces the Faza 2 "coming soon" stub. Two
/// sections: "Aldıqlarım" (every user's own [PinBoxOrder]s, always
/// shown first) and "Yaratdıqlarım" (the signed-in user's own [PinBox]
/// listings — only shown at all when [eligibleVenues] isn't empty, per
/// the product's explicit confirmation that this half of the screen is
/// for venue owners only, not every user).
class PinBoxMyBoxesScreen extends ConsumerStatefulWidget {
  final List<Venue> eligibleVenues;

  const PinBoxMyBoxesScreen({super.key, required this.eligibleVenues});

  @override
  ConsumerState<PinBoxMyBoxesScreen> createState() => _PinBoxMyBoxesScreenState();
}

class _PinBoxMyBoxesScreenState extends ConsumerState<PinBoxMyBoxesScreen> with SingleTickerProviderStateMixin {
  late final bool _showCreated = widget.eligibleVenues.isNotEmpty;
  late final TabController _tabController = TabController(length: _showCreated ? 2 : 1, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.pinboxMyBoxesTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
        bottom: _showCreated
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: ChatLightColors.inkFaint,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: loc.pinboxTabPurchased),
                  Tab(text: loc.pinboxTabCreated),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          physics: _showCreated ? null : const NeverScrollableScrollPhysics(),
          children: [
            const _MyOrdersList(),
            if (_showCreated) const _MyListingsList(),
          ],
        ),
      ),
    );
  }
}

class _MyOrdersList extends ConsumerWidget {
  const _MyOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(myPinBoxOrdersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
      error: (error, _) => Center(child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft))),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(
              loc.pinboxMyOrdersEmptyMessage,
              style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _OrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final PinBoxOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pinboxAsync = ref.watch(pinboxByIdProvider(order.pinboxId));

    return pinboxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pinbox) {
        if (pinbox == null) return const SizedBox.shrink();
        final (statusLabel, statusColor) = switch (order.status) {
          PinBoxOrderStatus.reserved => (loc.pinboxOrderStatusReserved, AppColors.primary),
          PinBoxOrderStatus.completed => (loc.pinboxOrderStatusCompleted, AppColors.gold),
          PinBoxOrderStatus.expired => (loc.pinboxOrderStatusExpired, AppColors.error),
        };

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PinBoxTicketScreen(orderId: order.id))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: pinbox.imageUrl != null
                        ? Image.network(pinbox.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: ChatLightColors.cardSurface,
                            alignment: Alignment.center,
                            child: const Icon(Icons.inventory_2_outlined, color: ChatLightColors.inkSoft),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pinbox.venueName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.pinboxTicketItemLabel(pinbox.title, order.quantity),
                        style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.amountPaid.toStringAsFixed(2)} AZN',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MyListingsList extends ConsumerWidget {
  const _MyListingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pinboxesAsync = ref.watch(myPinBoxesProvider);

    return pinboxesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
      error: (error, _) => Center(child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft))),
      data: (pinboxes) {
        if (pinboxes.isEmpty) {
          return Center(
            child: Text(
              loc.pinboxMyListingsEmptyMessage,
              style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: pinboxes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ListingCard(pinbox: pinboxes[index]),
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  final PinBox pinbox;

  const _ListingCard({required this.pinbox});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final (statusLabel, statusColor) = switch (pinbox.status) {
      'active' => (loc.pinboxListingStatusActive, AppColors.primary),
      'soldOut' => (loc.pinboxListingStatusSoldOut, AppColors.gold),
      'expired' => (loc.pinboxListingStatusExpired, ChatLightColors.inkFaint),
      'rejected' => (loc.pinboxListingStatusRejected, AppColors.error),
      _ => (loc.pinboxListingStatusPending, AppColors.gold),
    };
    final sold = pinbox.stockTotal - pinbox.stockRemaining;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: pinbox.imageUrl != null
                  ? Image.network(pinbox.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: ChatLightColors.cardSurface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.inventory_2_outlined, color: ChatLightColors.inkSoft),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pinbox.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
                const SizedBox(height: 2),
                Text(
                  loc.pinboxSoldCountLabel(sold, pinbox.stockTotal),
                  style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ),
          Text(
            '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
          ),
        ],
      ),
    );
  }
}
