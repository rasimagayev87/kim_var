import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../profile/presentation/providers/public_profile_providers.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../domain/entities/waitlist_entry.dart';
import '../providers/waitlist_providers.dart';

/// Owner-only "Növbə" management screen — reached from `MyVenuesScreen`'s
/// 3-dot menu. Live list of `waiting`/`called` entries in queue order,
/// each with the actions its current status allows, plus the
/// "Növbəni aktivləşdir/söndür" toggle.
class VenueWaitlistScreen extends ConsumerWidget {
  final Venue venue;

  const VenueWaitlistScreen({super.key, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final entriesAsync = ref.watch(venueWaitingListProvider(venue.id));

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
          loc.waitlistSectionTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
        ),
      ),
      body: Stack(
        children: [
          const ChatLightBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _EnabledToggleRow(venue: venue),
                ),
                Expanded(
                  child: entriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                    error: (error, _) => Center(
                      child: Text('$error', style: const TextStyle(color: ChatLightColors.inkSoft), textAlign: TextAlign.center),
                    ),
                    data: (entries) => entries.isEmpty
                        ? Center(
                            child: Text(
                              loc.waitlistEmptyMessage,
                              style: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _WaitlistEntryCard(venueId: venue.id, entry: entries[index]),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnabledToggleRow extends ConsumerWidget {
  final Venue venue;

  const _EnabledToggleRow({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final eligibleCategories = ref.watch(waitlistCategoryConfigProvider).valueOrNull ?? const {};
    // Reachable for a venue with existing entries even after its
    // category stops being eligible (see MyVenuesScreen's menu-item
    // gate) — but the toggle itself stays off and non-interactive in
    // that case, since re-enabling would open the feature back up to
    // an ineligible category. `disableVenueTooOldCategory` (Cloud
    // Function) has already forced it false server-side by the time
    // anyone could see this.
    final canToggle = eligibleCategories.contains(venue.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.waitlistEnableToggleLabel,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
            ),
          ),
          Switch(
            value: venue.waitlistEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: canToggle ? (value) => ref.read(waitlistControllerProvider).setEnabled(venueId: venue.id, enabled: value) : null,
          ),
        ],
      ),
    );
  }
}

class _WaitlistEntryCard extends ConsumerWidget {
  final String venueId;
  final WaitlistEntry entry;

  const _WaitlistEntryCard({required this.venueId, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final controller = ref.read(waitlistControllerProvider);
    final profile = ref.watch(publicProfileProvider(entry.userId)).valueOrNull;
    final name = (profile?.name ?? '').isEmpty ? loc.defaultUserName : profile!.name;
    final waitedMinutes = DateTime.now().difference(entry.joinedAt).inMinutes;
    final isCalled = entry.status == WaitlistEntryStatus.called;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ChatLightColors.cardSurface,
                backgroundImage: profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                child: profile?.photoUrl == null ? const Icon(Icons.person_outline, color: ChatLightColors.inkSoft) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${loc.waitlistPartySizeLabel(entry.partySize)} · ${isCalled ? loc.waitlistCalledStatusLabel : loc.waitlistWaitingSinceLabel(waitedMinutes)}',
                      style: const TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (!isCalled && entry.queuePosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${entry.queuePosition}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: isCalled
                ? [
                    TextButton(
                      onPressed: () => controller.markNoShow(venueId: venueId, entryId: entry.id),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: Text(loc.waitlistNoShowButton, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => controller.markSeated(venueId: venueId, entryId: entry.id),
                      style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      child: Text(loc.waitlistSeatedButton, style: const TextStyle(fontSize: 13)),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => controller.remove(venueId: venueId, entryId: entry.id),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: Text(loc.waitlistRemoveButton, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => controller.call(venueId: venueId, entryId: entry.id),
                      style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      child: Text(loc.waitlistCallButton, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
