import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/verification_guard.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../events/presentation/screens/my_venue_events_screen.dart';
import '../../../waitlist/presentation/screens/venue_waitlist_screen.dart';
import '../../domain/entities/venue.dart';
import '../../domain/venue_open_status.dart';
import '../providers/venue_providers.dart';
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
      backgroundColor: ChatLightColors.bg1,
      appBar: AppBar(
        backgroundColor: ChatLightColors.bg1.withValues(alpha: 0.92),
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
          const ChatLightBackground(),
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
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: venues.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _MyVenueCard(venue: venues[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _MyVenueCardAction { edit, seats, waitlist, events, delete }

class _MyVenueCard extends ConsumerWidget {
  final Venue venue;

  const _MyVenueCard({required this.venue});

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
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
            ListTile(
              leading: const Icon(Icons.event_seat_outlined, color: ChatLightColors.ink),
              title: Text(
                loc.seatsSheetTitle,
                style: const TextStyle(fontSize: 15, color: ChatLightColors.ink),
              ),
              onTap: () => Navigator.pop(sheetContext, _MyVenueCardAction.seats),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: ChatLightColors.ink),
              title: Text(
                loc.waitlistSectionTitle,
                style: const TextStyle(fontSize: 15, color: ChatLightColors.ink),
              ),
              onTap: () => Navigator.pop(sheetContext, _MyVenueCardAction.waitlist),
            ),
            ListTile(
              leading: const Icon(Icons.celebration_outlined, color: ChatLightColors.ink),
              title: Text(
                loc.eventMyEventsTitle,
                style: const TextStyle(fontSize: 15, color: ChatLightColors.ink),
              ),
              onTap: () => Navigator.pop(sheetContext, _MyVenueCardAction.events),
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
        Navigator.push(context, MaterialPageRoute(builder: (_) => VenueWaitlistScreen(venue: venue)));
      case _MyVenueCardAction.events:
        Navigator.push(context, MaterialPageRoute(builder: (_) => MyVenueEventsScreen(venue: venue)));
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
                            ? Image.network(venue.photoUrl!, fit: BoxFit.cover)
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
                              if (venue.status == 'pending' || needsRevision)
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
        status == 'needs_revision'
            ? loc.moderationStatusNeedsRevision
            : loc.moderationStatusPending,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (!await requireVerified(context, ref)) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateVenueScreen()),
                );
              },
              icon: const Icon(Icons.add, color: AppColors.onAccent),
              label: Text(loc.venueCreateTitle),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            ),
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
