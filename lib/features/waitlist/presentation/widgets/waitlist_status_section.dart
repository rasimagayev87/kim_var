import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/waitlist_entry.dart';
import '../providers/waitlist_providers.dart';
import 'waitlist_join_sheet.dart';

/// Non-owner "Sıraya yaz" section on `VenueProfileScreen` — a join
/// button when [Venue.waitlistEnabled] and the viewer has no active
/// entry yet, or their own live status (queue position / "called"
/// banner / leave button) once they've joined. An existing entry
/// always keeps showing even if the owner later disables new joins
/// (`waitlistEnabled: false` only hides the join button, never affects
/// people already in line — see `Venue.waitlistEnabled`'s doc comment).
class WaitlistStatusSection extends ConsumerWidget {
  final Venue venue;

  const WaitlistStatusSection({super.key, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(myWaitlistEntryProvider(venue.id)).valueOrNull;

    if (entry == null) {
      if (!venue.waitlistEnabled) return const SizedBox.shrink();
      return _JoinButton(venueId: venue.id);
    }

    return _MyEntryCard(venueId: venue.id, entry: entry);
  }
}

class _JoinButton extends StatelessWidget {
  final String venueId;

  const _JoinButton({required this.venueId});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showWaitlistJoinSheet(context, venueId),
        icon: const Icon(Icons.groups_outlined, size: 18),
        label: Text(loc.waitlistJoinButton),
      ),
    );
  }
}

class _MyEntryCard extends ConsumerWidget {
  final String venueId;
  final WaitlistEntry entry;

  const _MyEntryCard({required this.venueId, required this.entry});

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        content: Text(loc.waitlistLeaveConfirmMessage, style: const TextStyle(color: ChatLightColors.ink, fontSize: 14.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(loc.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.waitlistLeaveButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(waitlistControllerProvider).cancel(venueId: venueId, entryId: entry.id);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.waitlistGenericErrorMessage)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isCalled = entry.status == WaitlistEntryStatus.called;
    final color = isCalled ? AppColors.primary : ChatLightColors.ink;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCalled ? AppColors.primary.withValues(alpha: 0.1) : ChatLightColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: isCalled ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCalled)
                  Text(loc.waitlistCalledBanner, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color))
                else ...[
                  Text(
                    loc.waitlistMyPositionLabel(entry.queuePosition ?? '—'),
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (entry.queuePosition ?? 1) <= 1 ? loc.waitlistFrontOfLineLabel : loc.waitlistAheadOfYouLabel((entry.queuePosition ?? 1) - 1),
                    style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => _leave(context, ref),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(loc.waitlistLeaveButton, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
