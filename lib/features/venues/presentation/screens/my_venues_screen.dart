import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/category_capabilities.dart';
import '../../../../core/payments/epoint_checkout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../pinbox/presentation/screens/pinbox_redeem_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../waitlist/presentation/providers/waitlist_providers.dart';
import '../../../waitlist/presentation/screens/venue_waitlist_screen.dart';
import '../../domain/entities/venue.dart';
import '../../domain/venue_open_status.dart';
import '../../domain/business_offer_acceptance.dart';
import '../providers/venue_providers.dart';
import '../../../offers/domain/entities/offer.dart' show freeCampaignQuotaFor;
import '../widgets/business_offer_consent_row.dart';
import '../widgets/business_offer_updated_banner.dart';
import '../widgets/seat_count_editor_sheet.dart';
import 'create_venue_screen.dart';

/// Owner-only management screen — every venue the signed-in user has
/// submitted, regardless of their current position or selected radius
/// (unlike the Kəşf et → Məkanlar list, which only shows venues within
/// range). Backed by [myVenuesProvider]'s realtime `watchMyVenues`
/// stream, so an edit/delete here reflects immediately.
class MyVenuesScreen extends ConsumerWidget {
  const MyVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venuesAsync = ref.watch(myVenuesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: ChatLightColors.ink,
          ),
        ),
        title: Text(
          loc.venueMyVenuesTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ChatLightColors.ink,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: venuesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  '$error',
                  style: const TextStyle(color: ChatLightColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (allVenues) {
                // Rejected venues drop out of this list entirely — the
                // owner already got the rejection + reason as a
                // notification (see onVenueUpdated in
                // functions/src/index.ts); there's no "silinmiş
                // elementlər" archive screen to keep them findable in,
                // per the product decision to keep this simple.
                final venues = allVenues
                    .where((v) => v.status != 'rejected')
                    .toList();
                if (venues.isEmpty) return _EmptyMyVenues(loc: loc, ref: ref);
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    BusinessOfferUpdatedBanner(venues: venues),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: venues.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _MyVenueCard(venue: venues[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _MyVenueCardAction { edit, seats, waitlist, pinboxRedeem, delete }

class _MyVenueCard extends ConsumerWidget {
  final Venue venue;

  const _MyVenueCard({required this.venue});

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);

    // Same "eligible category OR existing history" rule the waitlist
    // feature has always used — see `waitlistCategoryConfigProvider`'s
    // doc comment. (Tədbirlər/events management moved out of this menu
    // entirely — it now lives under Kəşf et → Fürsətlər's own "manage"
    // icon, see `discover_tab.dart`'s `_openMyEvents`.)
    // `category.capabilities.canUseWaitlist`/`canUsePinBox` (see
    // lib/core/constants/category_capabilities.dart) is checked FIRST
    // and wins outright for offer-only categories — even the "existing
    // history" carve-out below never applies to them, since a category
    // that can never join a waitlist can also never have accrued one.
    final waitlistCapable = venue.category.capabilities.canUseWaitlist;
    final eligibleWaitlistCategories = await ref.read(
      waitlistCategoryConfigProvider.future,
    );
    var showWaitlistMenuItem =
        waitlistCapable && eligibleWaitlistCategories.contains(venue.category);
    if (!showWaitlistMenuItem && waitlistCapable) {
      showWaitlistMenuItem = await ref
          .read(waitlistRepositoryProvider)
          .hasAnyEntry(venue.id);
    }

    // Boş yer sayı shares the SAME eligibility list as the waitlist
    // (explicit product decision — the two features are one "live
    // walk-in operations" concept, see `waitlistCategoryConfigProvider`'s
    // doc comment). Unlike Növbə/Tədbirlər above, there's deliberately
    // no "existing history" carve-out here: an ineligible category
    // hides this row outright, full stop.
    final showSeatsMenuItem =
        waitlistCapable && eligibleWaitlistCategories.contains(venue.category);

    // PinBox eligibility is a hardcoded product decision, not
    // Firestore-config-driven (see `kPinboxEligibleVenueCategories`'s own
    // doc comment) — no "existing history" carve-out, an ineligible
    // category hides this row outright, same as Boş yer sayı above.
    final showPinboxRedeemMenuItem =
        venue.category.capabilities.canUsePinBox &&
        kPinboxEligibleVenueCategories.contains(venue.category);
    if (!context.mounted) return;

    final action = await showModalBottomSheet<_MyVenueCardAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: ChatLightColors.ink,
              ),
              title: Text(
                loc.venueEditTitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: ChatLightColors.ink,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, _MyVenueCardAction.edit),
            ),
            if (showSeatsMenuItem)
              ListTile(
                leading: const Icon(
                  Icons.event_seat_outlined,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.seatsSheetTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ChatLightColors.ink,
                  ),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _MyVenueCardAction.seats),
              ),
            if (showWaitlistMenuItem)
              ListTile(
                leading: const Icon(
                  Icons.groups_outlined,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.waitlistSectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ChatLightColors.ink,
                  ),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _MyVenueCardAction.waitlist),
              ),
            if (showPinboxRedeemMenuItem)
              ListTile(
                leading: const Icon(
                  Icons.qr_code_scanner_outlined,
                  color: ChatLightColors.ink,
                ),
                title: Text(
                  loc.pinboxRedeemMenuLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    color: ChatLightColors.ink,
                  ),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _MyVenueCardAction.pinboxRedeem,
                ),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                loc.venueDeleteMenuOption,
                style: const TextStyle(fontSize: 15, color: AppColors.error),
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, _MyVenueCardAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _MyVenueCardAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateVenueScreen(existingVenue: venue),
          ),
        );
      case _MyVenueCardAction.seats:
        showSeatCountEditorSheet(context, venue);
      case _MyVenueCardAction.waitlist:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VenueWaitlistScreen(venue: venue)),
        );
      case _MyVenueCardAction.pinboxRedeem:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PinBoxRedeemScreen(venue: venue)),
        );
      case _MyVenueCardAction.delete:
        _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          loc.venueDeleteMenuOption,
          style: const TextStyle(
            color: ChatLightColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          loc.venueDeleteConfirmMessage,
          style: const TextStyle(
            color: ChatLightColors.inkSoft,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.actionDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(venueControllerProvider)
        .deleteVenue(
          venue.id,
          onError: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.venueGenericErrorMessage)),
            );
          },
        );

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.venueDeletedNotice)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final needsRevision = venue.status == 'needs_revision';
    final awaitingFirstPayment = venue.status == 'awaiting_payment';
    // Düzəliş Prompt 6 / PAY-10 — `subscription_overdue` (set by
    // `renewVenueSubscriptions` once a venue has been unpaid past the
    // grace window) is, by definition, always overdue — no need to
    // separately check `subscriptionRenewsAt` for that branch. Keeping
    // the SAME banner/pay-button (`_SubscriptionOverdueBanner`) visible
    // for both `approved`-but-overdue AND `subscription_overdue` is
    // what actually matters here: `retryVenueSubscriptionPayment`
    // itself never checks `status` at all, so the owner's only way
    // back in is this UI still showing the "Ödə" button once suspended
    // — if this condition stayed `status == 'approved'` only, a
    // suspended venue would lose its own recovery path from the app.
    final isSubscriptionSuspended = venue.status == 'subscription_overdue';
    final isOverdue =
        isSubscriptionSuspended ||
        (venue.status == 'approved' &&
            venue.subscriptionRenewsAt != null &&
            venue.subscriptionRenewsAt!.isBefore(DateTime.now()));

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
                        child: venue.photoUrl != null
                            ? AppImage(
                                venue.photoUrl!,
                                thumbnail: true,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: ChatLightColors.cardSurface,
                                alignment: Alignment.center,
                                child: Icon(
                                  venueCategoryIcon(venue.category),
                                  color: ChatLightColors.inkSoft,
                                  size: 26,
                                ),
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    venue.name,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: ChatLightColors.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (venue.isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 15,
                                    color: AppColors.gold,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  venueCategoryLabel(loc, venue.category),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: ChatLightColors.inkSoft,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (venue.status == 'pending' ||
                                  needsRevision ||
                                  awaitingFirstPayment ||
                                  isSubscriptionSuspended)
                                _ModerationStatusBadge(status: venue.status)
                              else
                                _OpenStatusBadge(
                                  isOpen: isVenueOpenNow(
                                    venue.openingHours,
                                    DateTime.now(),
                                  ),
                                ),
                            ],
                          ),
                          if (venue.address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              venue.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ChatLightColors.inkFaint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  reviewNote: venue.reviewNote,
                  revisionDeadline: venue.revisionDeadline,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateVenueScreen(existingVenue: venue),
                    ),
                  ),
                ),
              if (awaitingFirstPayment) _FirstPaymentBanner(venueId: venue.id),
              if (venue.firstPaymentAnnouncementPending)
                _FirstPaymentConfirmedCard(
                  venueId: venue.id,
                  isFoundingVenue: venue.isFoundingVenue,
                  subscriptionRenewsAt: venue.subscriptionRenewsAt,
                ),
              if (isOverdue)
                _SubscriptionOverdueBanner(
                  venueId: venue.id,
                  offerAcceptedVersion: venue.offerAcceptedVersion,
                ),
              // The subscription's free-campaign allowance. Shown only
              // while a paid period is actually running — an overdue
              // venue has no allowance at all (its counter is frozen,
              // see `currentSubscriptionPeriodStart` server-side), and
              // showing "3/5 left" next to an unpaid-subscription
              // banner would contradict it.
              if (!isOverdue &&
                  venue.subscriptionRenewsAt != null &&
                  DateTime.now().isBefore(venue.subscriptionRenewsAt!))
                _FreeCampaignQuotaRow(venue: venue),
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
                  child: Icon(
                    Icons.more_vert_outlined,
                    size: 18,
                    color: ChatLightColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending/needs_revision pill — same 10.5px/w700 pill recipe as
/// [_OpenStatusBadge], just amber-toned so it reads as "in progress",
/// not "closed".
class _ModerationStatusBadge extends StatelessWidget {
  final String status;

  const _ModerationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    const color = AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        switch (status) {
          'needs_revision' => loc.moderationStatusNeedsRevision,
          'awaiting_payment' => loc.moderationStatusAwaitingPayment,
          'subscription_overdue' => loc.moderationStatusSubscriptionOverdue,
          _ => loc.moderationStatusPending,
        },
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Shown under a needs_revision card — the reviewer's note plus a
/// direct "Düzəliş et" CTA (in addition to the same action already
/// reachable via the overflow menu, since this is the one status where
/// the owner needs to act, not just glance at a badge).
class _NeedsRevisionBanner extends StatelessWidget {
  final String? reviewNote;
  final DateTime? revisionDeadline;
  final VoidCallback onEdit;

  const _NeedsRevisionBanner({
    required this.reviewNote,
    required this.revisionDeadline,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final daysLeft = revisionDeadline
        ?.difference(DateTime.now())
        .inDays
        .clamp(0, 999);

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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ChatLightColors.ink,
                          ),
                        ),
                        TextSpan(
                          text: reviewNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ChatLightColors.inkSoft,
                          ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ChatLightColors.ink,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  loc.venueEditTitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (daysLeft != null) ...[
            const SizedBox(height: 6),
            Text(
              loc.venueRevisionDaysLeft(daysLeft),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown while [Venue.status] is 'awaiting_payment' — the venue's FIRST
/// subscription charge (`submitVenue`) never went through, so it's
/// invisible to everyone, not even in the moderation queue yet. Gives
/// the owner a way back into that same checkout if they abandoned it or
/// a previous Epoint attempt failed. Mirrors offers' own
/// `_AwaitingPaymentBanner` (venues just use `presentEpointCheckout`'s
/// sheet here, same as `_SubscriptionOverdueBanner` below, rather than
/// launching the card URL directly).
class _FirstPaymentBanner extends ConsumerStatefulWidget {
  final String venueId;

  const _FirstPaymentBanner({required this.venueId});

  @override
  ConsumerState<_FirstPaymentBanner> createState() =>
      _FirstPaymentBannerState();
}

class _FirstPaymentBannerState extends ConsumerState<_FirstPaymentBanner> {
  bool _loading = false;

  Future<void> _pay() async {
    if (_loading) return;
    setState(() => _loading = true);
    final loc = AppLocalizations.of(context);

    try {
      final result = await ref
          .read(venueRepositoryProvider)
          .retryVenueCreationPayment(widget.venueId);
      if (!mounted) return;
      await presentEpointCheckout(
        context,
        checkoutUrl: result.checkoutUrl,
        paymentId: result.paymentId,
        feeAmount: result.feeAmount,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.venueSubscriptionRetryErrorMessage)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.venueFirstPaymentBannerText,
              style: const TextStyle(
                fontSize: 12.5,
                color: ChatLightColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    loc.venueSubscriptionPayButton,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown once [Venue.firstPaymentAnnouncementPending] is true — the
/// FIRST subscription charge just cleared. Distinct tone from the other
/// banners here (positive confirmation, not "needs action"), and reads
/// [isFoundingVenue]/[subscriptionRenewsAt] live off the same venue
/// object this whole card list already rebuilds from, so if founding
/// status (and its free 2nd cycle) lands via `assignFoundingVenueIfEligible`
/// WHILE this card is still showing, it flips from the plain confirmation
/// wording to the founding one on its own — no polling, no stale date.
class _FirstPaymentConfirmedCard extends ConsumerStatefulWidget {
  final String venueId;
  final bool isFoundingVenue;
  final DateTime? subscriptionRenewsAt;

  const _FirstPaymentConfirmedCard({
    required this.venueId,
    required this.isFoundingVenue,
    required this.subscriptionRenewsAt,
  });

  @override
  ConsumerState<_FirstPaymentConfirmedCard> createState() =>
      _FirstPaymentConfirmedCardState();
}

class _FirstPaymentConfirmedCardState
    extends ConsumerState<_FirstPaymentConfirmedCard> {
  bool _dismissing = false;

  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    // Optimistic — this is purely a UI-dismiss flag with no
    // moderation/payment consequence either way, so there's nothing to
    // roll back on failure; the card just stays until the next
    // successful attempt (or reappears on next stream update if the
    // write genuinely failed).
    await ref
        .read(venueRepositoryProvider)
        .dismissFirstPaymentAnnouncement(widget.venueId);
    if (mounted) setState(() => _dismissing = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final renewsAt = widget.subscriptionRenewsAt;
    final dateText = renewsAt != null
        ? DateFormat('dd.MM.yyyy').format(renewsAt)
        : '—';
    final text = widget.isFoundingVenue
        ? loc.venueFirstPaymentConfirmedFoundingText(dateText)
        : loc.venueFirstPaymentConfirmedText(dateText);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: ChatLightColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _dismissing ? null : _dismiss,
            child: _dismissing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    loc.venueFirstPaymentConfirmedDismiss,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown when [Venue.subscriptionRenewsAt] is in the past — the owner's
/// way to complete the overdue Epoint checkout `renewVenueSubscriptions`
/// (scheduled Cloud Function) already created, or to get a fresh one if
/// that link expired/was abandoned. Same layout/pattern as offers' own
/// `_AwaitingPaymentBanner`.
class _SubscriptionOverdueBanner extends ConsumerStatefulWidget {
  final String venueId;
  final String? offerAcceptedVersion;

  const _SubscriptionOverdueBanner({
    required this.venueId,
    required this.offerAcceptedVersion,
  });

  @override
  ConsumerState<_SubscriptionOverdueBanner> createState() =>
      _SubscriptionOverdueBannerState();
}

class _SubscriptionOverdueBannerState
    extends ConsumerState<_SubscriptionOverdueBanner> {
  bool _loading = false;

  Future<void> _pay() async {
    if (_loading) return;
    setState(() => _loading = true);
    final loc = AppLocalizations.of(context);

    try {
      final config = ref.read(appConfigProvider);
      final needsReaccept = needsBusinessOfferReacceptance(
        acceptedVersion: widget.offerAcceptedVersion,
        currentVersion: config.businessOfferVersion,
      );

      ({String version, String documentUrl, String appVersion})?
      offerAcceptance;
      if (needsReaccept) {
        final accepted = await showBusinessOfferReacceptSheet(context);
        if (!accepted) return;
        final packageInfo = await PackageInfo.fromPlatform();
        offerAcceptance = (
          version: config.businessOfferVersion,
          documentUrl: config.urlBusinessOffer,
          appVersion: packageInfo.version,
        );
      }

      final result = await ref
          .read(venueRepositoryProvider)
          .retryVenueSubscriptionPayment(
            widget.venueId,
            offerAcceptance: offerAcceptance,
          );
      if (!mounted) return;
      await presentEpointCheckout(
        context,
        checkoutUrl: result.checkoutUrl,
        paymentId: result.paymentId,
        feeAmount: result.feeAmount,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.venueSubscriptionRetryErrorMessage)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.venueSubscriptionOverdueBannerText,
              style: const TextStyle(
                fontSize: 12.5,
                color: ChatLightColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    loc.venueSubscriptionPayButton,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMyVenues extends StatelessWidget {
  final AppLocalizations loc;
  final WidgetRef ref;

  const _EmptyMyVenues({required this.loc, required this.ref});

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: ChatLightColors.inkFaint,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.venueMyVenuesEmptyTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ChatLightColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              loc.venueMyVenuesEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: ChatLightColors.inkFaint,
                height: 1.5,
              ),
            ),
            if (ref.read(profileControllerProvider).hasBusinessAccess) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateVenueScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: AppColors.onAccent),
                label: Text(loc.venueCreateTitle),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Same pill as `discover_tab.dart`'s private `_OpenStatusBadge` —
/// intentionally duplicated rather than shared, since it's a single
/// small stateless widget and the two screens have no other coupling.
class _OpenStatusBadge extends StatelessWidget {
  final bool isOpen;

  const _OpenStatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = isOpen ? AppColors.primary : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? loc.venueOpenNowLabel : loc.venueClosedNowLabel,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// "Pulsuz kampaniya: 2/5" plus when the allowance renews.
///
/// A read-only mirror of `venues/{id}.freeCampaignsUsed`, which only
/// the server writes (firestore.rules' venue blocklist). The quota
/// itself is derived from the venue's subscription tier — see
/// [freeCampaignQuotaFor].
class _FreeCampaignQuotaRow extends StatelessWidget {
  const _FreeCampaignQuotaRow({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final quota = freeCampaignQuotaFor(venue.category);
    if (quota == 0) return const SizedBox.shrink();
    final used = venue.freeCampaignsUsed.clamp(0, quota);
    final renewsAt = venue.subscriptionRenewsAt!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            loc.venueFreeCampaignsLabel(used, quota),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ChatLightColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.offerFreeCampaignsRenewOn(
                '${renewsAt.day.toString().padLeft(2, '0')}.${renewsAt.month.toString().padLeft(2, '0')}.${renewsAt.year}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ChatLightColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
