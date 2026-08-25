import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/pinbox.dart';
import '../../domain/entities/pinbox_order.dart';
import '../providers/pinbox_providers.dart';
import 'create_pinbox_screen.dart';
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
          PinBoxOrderStatus.awaitingPayment => (loc.pinboxOrderStatusAwaitingPayment, AppColors.gold),
          PinBoxOrderStatus.reserved => (loc.pinboxOrderStatusReserved, AppColors.primary),
          PinBoxOrderStatus.paymentFailed => (loc.pinboxOrderStatusPaymentFailed, AppColors.error),
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
                        ? AppImage(pinbox.imageUrl!, thumbnail: true, fit: BoxFit.cover)
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

enum _ListingCardAction { edit, delete }

class _ListingCard extends ConsumerWidget {
  final PinBox pinbox;

  const _ListingCard({required this.pinbox});

  /// `status` only ever flips to `'expired'` if something explicitly
  /// writes it — nothing does that on a schedule the moment
  /// [PinBox.pickupWindowEnd] passes (see `reservePinBoxOrder`'s own
  /// doc comment on this exact gap), so a box that never sold out
  /// stays `'active'` in Firestore forever after its window ends. This
  /// derives the real-time answer instead of trusting the stale field.
  bool get _isPastPickupWindow => pinbox.pickupWindowEnd.isBefore(DateTime.now());

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    // A sold-out or expired box has nothing left to edit — its stock/
    // pickup window are already final, only removing the listing makes
    // sense at that point. 'pending'/'rejected' still need editing —
    // that's how `resubmitPinBox` (see `create_pinbox_screen.dart`)
    // gets back to review after a fix, so this only ever excludes the
    // two genuinely-final states.
    final canEdit = pinbox.status != 'soldOut' && pinbox.status != 'expired' && !_isPastPickupWindow;
    final action = await showModalBottomSheet<_ListingCardAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: ChatLightColors.ink),
                title: Text(loc.pinboxEditTitle, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
                onTap: () => Navigator.pop(sheetContext, _ListingCardAction.edit),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(loc.pinboxDeleteMenuOption, style: const TextStyle(fontSize: 15, color: AppColors.error)),
              onTap: () => Navigator.pop(sheetContext, _ListingCardAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == _ListingCardAction.edit) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePinBoxScreen(existingPinBox: pinbox)));
    } else {
      _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(loc.pinboxDeleteMenuOption, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w700)),
        content: Text(
          loc.pinboxDeleteConfirmMessage,
          style: const TextStyle(color: ChatLightColors.inkSoft, fontSize: 14.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(pinboxControllerProvider).deletePinBox(
          pinbox.id,
          onError: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
          },
        );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.pinboxDeletedNotice)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final (statusLabel, statusColor) = switch (pinbox.status) {
      'active' when _isPastPickupWindow => (loc.pinboxListingStatusExpired, ChatLightColors.inkFaint),
      'active' => (loc.pinboxListingStatusActive, AppColors.primary),
      'soldOut' => (loc.pinboxListingStatusSoldOut, AppColors.gold),
      'expired' => (loc.pinboxListingStatusExpired, ChatLightColors.inkFaint),
      'rejected' => (loc.pinboxListingStatusRejected, AppColors.error),
      'needs_revision' => (loc.pinboxListingStatusNeedsRevision, AppColors.gold),
      _ => (loc.pinboxListingStatusPending, AppColors.gold),
    };
    final sold = pinbox.stockTotal - pinbox.stockRemaining;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: pinbox.imageUrl != null
                            ? AppImage(pinbox.imageUrl!, thumbnail: true, fit: BoxFit.cover)
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
                          Padding(
                            padding: const EdgeInsets.only(right: 28),
                            child: Text(
                              pinbox.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.pinboxSoldCountLabel(sold, pinbox.stockTotal),
                            style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
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
                              const Spacer(),
                              Text(
                                '${pinbox.pinboxPrice.toStringAsFixed(2)} AZN',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: ChatLightColors.cardSurface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openMenu(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.more_vert_outlined, size: 18, color: ChatLightColors.inkSoft),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (pinbox.status == 'needs_revision')
            _PinboxNeedsRevisionBanner(
              reviewNote: pinbox.reviewNote,
              onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePinBoxScreen(existingPinBox: pinbox))),
            ),
        ],
      ),
    );
  }
}

/// Mirrors offers'/venues' own `_NeedsRevisionBanner` — no deadline
/// countdown here, since PinBox has no `revisionDeadline` field to
/// begin with (no upfront listing fee to protect with one).
class _PinboxNeedsRevisionBanner extends StatelessWidget {
  final String? reviewNote;
  final VoidCallback onEdit;

  const _PinboxNeedsRevisionBanner({required this.reviewNote, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (reviewNote != null && reviewNote!.trim().isNotEmpty)
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${loc.moderationReviewNotePrefix}: ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                    ),
                    TextSpan(text: reviewNote, style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft)),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Expanded(
              child: Text(
                loc.moderationStatusNeedsRevision,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
              ),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(loc.pinboxEditTitle, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
