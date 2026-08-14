import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../waitlist/presentation/providers/waitlist_providers.dart';
import '../../domain/entities/venue.dart';

/// Small live status card near the top of [VenueProfileScreen] —
/// green/yellow/red by [Venue.seatAvailabilityLevel], with a ticking
/// "X dəq əvvəl yeniləndi" caption underneath. Renders nothing at all
/// when [Venue.availableSeats] is null (the owner has never turned
/// this feature on) — a missing card reads correctly as "no seat info
/// here," where a "0 seats" card would falsely imply the venue is full.
/// Also hidden outright when the venue's category isn't eligible for
/// this feature (see `waitlistCategoryConfigProvider`'s doc comment —
/// shared with the waitlist, by explicit product decision), regardless
/// of whether [Venue.availableSeats] happens to still be set from
/// before that restriction existed.
///
/// Reusable on purpose: takes a plain [Venue], not a provider — any
/// screen already holding a live [Venue] (from `venueByIdProvider` or
/// otherwise) can drop this in and it stays in sync for free, since
/// the caller re-renders it whenever their own venue stream ticks.
class SeatAvailabilityCard extends ConsumerStatefulWidget {
  final Venue venue;

  const SeatAvailabilityCard({super.key, required this.venue});

  @override
  ConsumerState<SeatAvailabilityCard> createState() => _SeatAvailabilityCardState();
}

class _SeatAvailabilityCardState extends ConsumerState<SeatAvailabilityCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the "X dəq əvvəl" caption advancing even when nothing else
    // about the venue changes — the Firestore stream only rebuilds this
    // widget on a real write, not just because time passed.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.venue.seatAvailabilityLevel;
    if (level == null) return const SizedBox.shrink();

    final eligibleCategories = ref.watch(waitlistCategoryConfigProvider).valueOrNull ?? const {};
    if (!eligibleCategories.contains(widget.venue.category)) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context);
    final seats = widget.venue.availableSeats!;
    // AppColors.primary (cyan), not green, for the "plenty" state — this
    // codebase's design system replaced every green accent with the
    // brand cyan; the 🟢 emoji itself is unavoidably green (a fixed
    // Unicode glyph), but the card's own chrome follows the app's
    // palette like everywhere else.
    final (color, emoji, label) = switch (level) {
      SeatAvailabilityLevel.plenty => (AppColors.primary, '🟢', loc.seatsAvailableLabel(seats)),
      SeatAvailabilityLevel.low => (AppColors.gold, '🟡', loc.seatsLowLabel(seats)),
      SeatAvailabilityLevel.full => (AppColors.error, '🔴', loc.seatsFullLabel),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        if (widget.venue.seatsUpdatedAt != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              loc.seatsUpdatedAgoLabel(formatRelativeTime(widget.venue.seatsUpdatedAt!, loc)),
              style: const TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
            ),
          ),
        ],
      ],
    );
  }
}
