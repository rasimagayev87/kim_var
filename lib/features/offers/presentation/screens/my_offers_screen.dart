import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../venues/domain/entities/venue.dart' show venueCategoryIcon;
import '../../domain/entities/offer.dart';
import '../providers/offer_providers.dart';
import 'create_offer_screen.dart';

/// Owner-only management screen — every offer the signed-in user has
/// published, regardless of expiry (unlike the Kəşf et → Təkliflər
/// list, which only shows active, non-expired ones). Mirrors
/// `MyVenuesScreen` exactly.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final offersAsync = ref.watch(myOffersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ChatLightColors.ink),
        ),
        title: Text(
          loc.offerMyOffersTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: offersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
              error: (error, _) => Center(
                child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft), textAlign: TextAlign.center),
              ),
              data: (allOffers) {
                // Rejected offers drop out of this list entirely — same
                // reasoning as MyVenuesScreen's own rejected filter.
                final offers = allOffers.where((o) => o.status != 'rejected').toList();
                if (offers.isEmpty) return _EmptyMyOffers(loc: loc, ref: ref);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: offers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _MyOfferCard(offer: offers[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _MyOfferCardAction { edit, delete }

class _MyOfferCard extends ConsumerWidget {
  final Offer offer;

  const _MyOfferCard({required this.offer});

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_MyOfferCardAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: ChatLightColors.ink),
              title: Text(loc.offerEditTitle, style: const TextStyle(fontSize: 15, color: ChatLightColors.ink)),
              onTap: () => Navigator.pop(sheetContext, _MyOfferCardAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(loc.offerDeleteMenuOption, style: const TextStyle(fontSize: 15, color: AppColors.error)),
              onTap: () => Navigator.pop(sheetContext, _MyOfferCardAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == _MyOfferCardAction.edit) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOfferScreen(existingOffer: offer)));
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
        title: Text(loc.offerDeleteMenuOption, style: const TextStyle(color: ChatLightColors.ink, fontWeight: FontWeight.w700)),
        content: Text(
          loc.offerDeleteConfirmMessage,
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

    final success = await ref.read(offerControllerProvider).deleteOffer(
          offer.id,
          onError: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerGenericErrorMessage)));
          },
        );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerDeletedNotice)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final needsRevision = offer.status == 'needs_revision';
    final happyHourInactive =
        offer.status == 'approved' && !offer.isExpired && offer.offerType == OfferType.happyHour && !offer.happyHourActive;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: offer.imageUrl != null
                            ? AppImage(offer.imageUrl!, thumbnail: true, fit: BoxFit.cover)
                            : Container(
                                color: ChatLightColors.cardSurface,
                                alignment: Alignment.center,
                                child: Icon(venueCategoryIcon(offer.category), color: ChatLightColors.inkSoft, size: 26),
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
                              offer.title,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  offer.venueName,
                                  style: const TextStyle(fontSize: 13, color: ChatLightColors.inkSoft),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (offer.status == 'pending' || offer.status == 'awaiting_payment' || needsRevision)
                                _ModerationStatusBadge(status: offer.status)
                              else
                                _OfferStatusBadge(isExpired: offer.isExpired, happyHourInactive: happyHourInactive),
                            ],
                          ),
                          if (happyHourInactive && offer.activeHours != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              loc.offerHappyHourNextActiveLabel(offer.activeHours!.start),
                              style: const TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (needsRevision)
                _NeedsRevisionBanner(
                  reviewNote: offer.reviewNote,
                  revisionDeadline: offer.revisionDeadline,
                  onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOfferScreen(existingOffer: offer))),
                ),
              if (offer.status == 'awaiting_payment') _AwaitingPaymentBanner(offerId: offer.id),
            ],
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
    );
  }
}

class _EmptyMyOffers extends StatelessWidget {
  final AppLocalizations loc;
  final WidgetRef ref;

  const _EmptyMyOffers({required this.loc, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: const Icon(Icons.local_offer_outlined, color: ChatLightColors.inkFaint, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              loc.offerMyOffersEmptyTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              loc.offerMyOffersEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: ChatLightColors.inkFaint, height: 1.5),
            ),
            if (ref.read(profileControllerProvider).hasBusinessAccess) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOfferScreen()));
                },
                icon: const Icon(Icons.add, color: AppColors.onAccent),
                label: Text(loc.offerCreateTitle),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Same pill shape as Venues' own status badge — intentionally
/// duplicated (single small stateless widget, no other coupling).
class _OfferStatusBadge extends StatelessWidget {
  final bool isExpired;

  /// True for an approved, non-expired Happy Hour offer that's outside
  /// its daily window right now — distinct from [isExpired] (the
  /// listing itself is still live, just not "on" this minute).
  final bool happyHourInactive;

  const _OfferStatusBadge({required this.isExpired, this.happyHourInactive = false});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = (isExpired || happyHourInactive) ? AppColors.textMuted : AppColors.primary;
    final label = isExpired
        ? loc.offerStatusExpired
        : happyHourInactive
            ? loc.offerHappyHourInactiveLabel
            : loc.offerStatusActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Pending/needs_revision pill — mirrors venues' own
/// `_ModerationStatusBadge` exactly (duplicated per this file's own
/// "no coupling between the two management screens" convention).
class _ModerationStatusBadge extends StatelessWidget {
  final String status;

  const _ModerationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    const color = AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(
        switch (status) {
          'needs_revision' => loc.moderationStatusNeedsRevision,
          'awaiting_payment' => loc.moderationStatusAwaitingPayment,
          _ => loc.moderationStatusPending,
        },
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// "Ödəniş gözlənilir" — shown while [Offer.status] is
/// 'awaiting_payment', with a way back into the Epoint checkout for an
/// owner who abandoned or whose previous attempt failed. Mirrors
/// `_NeedsRevisionBanner`'s layout, distinct content/action.
class _AwaitingPaymentBanner extends ConsumerStatefulWidget {
  final String offerId;

  const _AwaitingPaymentBanner({required this.offerId});

  @override
  ConsumerState<_AwaitingPaymentBanner> createState() => _AwaitingPaymentBannerState();
}

class _AwaitingPaymentBannerState extends ConsumerState<_AwaitingPaymentBanner> {
  bool _loading = false;

  Future<void> _retry() async {
    if (_loading) return;
    setState(() => _loading = true);
    final loc = AppLocalizations.of(context);

    final result = await ref.read(offerControllerProvider).retryOfferPayment(widget.offerId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.offerRetryPaymentErrorMessage)));
      return;
    }
    await launchUrl(Uri.parse(result.checkoutUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.offerAwaitingPaymentBannerText,
              style: const TextStyle(fontSize: 12.5, color: ChatLightColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loading ? null : _retry,
            child: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.offerRetryPaymentButton, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Mirrors venues' own `_NeedsRevisionBanner` exactly.
class _NeedsRevisionBanner extends StatelessWidget {
  final String? reviewNote;
  final DateTime? revisionDeadline;
  final VoidCallback onEdit;

  const _NeedsRevisionBanner({required this.reviewNote, required this.revisionDeadline, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final daysLeft = revisionDeadline?.difference(DateTime.now()).inDays.clamp(0, 999);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        TextSpan(
                          text: reviewNote,
                          style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                        ),
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
                child: Text(loc.offerEditTitle, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (daysLeft != null) ...[
            const SizedBox(height: 6),
            Text(
              loc.venueRevisionDaysLeft(daysLeft),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
