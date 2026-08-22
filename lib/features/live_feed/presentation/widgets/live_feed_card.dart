import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../domain/entities/live_feed_item.dart';
import 'live_feed_palette.dart';

/// Type still decides which GLYPH shows (so audience/event/offer/seat/
/// birthday stay instantly tell-apart-able at a glance) — color no
/// longer does, see [liveFeedGradientForKey].
IconData iconForLiveFeedType(LiveFeedType type) {
  return switch (type) {
    LiveFeedType.audience => Icons.groups_rounded,
    LiveFeedType.event => Icons.celebration_rounded,
    LiveFeedType.offer => Icons.local_offer_rounded,
    LiveFeedType.seatAvailable => Icons.event_seat_rounded,
    LiveFeedType.birthday => Icons.cake_rounded,
    LiveFeedType.pinbox => Icons.inventory_2_rounded,
  };
}

/// One row in the Canlı card list — 34x34 rounded-square icon
/// container, title/subtitle, trailing chevron. The icon container is
/// a per-venue gradient (see `live_feed_palette.dart`) rather than a
/// flat per-type color: two offer cards for two different venues get
/// two different premium color pairs, while every card about the same
/// venue (an offer, an event, a "boş yer" reading) shares one — colour
/// now signals "which venue", the icon glyph signals "what kind of
/// thing". Text/background roles reuse the app's own [AppColors] (the
/// closest existing named constants to the design spec's literal hex
/// values — e.g. `AppColors.background` is 0xFFEEF1F4 against the
/// spec's 0xFFF4F6F8, a one-character difference).
///
/// [LiveFeedType.audience] is purely informational — it isn't about
/// any one venue's own page, so it has no tap target: no ripple, no
/// trailing chevron. Every other type navigates to its underlying
/// venue/offer/event, per the "Canlı" tab tap-behavior spec.
class LiveFeedCard extends StatelessWidget {
  final LiveFeedItem item;
  final VoidCallback onTap;

  const LiveFeedCard({super.key, required this.item, required this.onTap});

  bool get _isTappable => item.type != LiveFeedType.audience;

  /// Whether to show the venue's own profile photo instead of the
  /// generic per-type glyph — never for [LiveFeedType.audience] (a
  /// system announcement, not venue content — [item.photoUrl] is never
  /// populated for that type to begin with, but this stays explicit
  /// rather than relying on that alone), and only when the venue
  /// actually has one set. Same `photoUrl != null` fallback rule every
  /// other venue-photo call site in the app already uses.
  bool get _showVenuePhoto => _isTappable && item.photoUrl != null;

  @override
  Widget build(BuildContext context) {
    final icon = iconForLiveFeedType(item.type);
    final gradient = liveFeedGradientForKey(item.venueId);

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _isTappable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gradient.glow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
          ),
          child: Row(
            children: [
              _showVenuePhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: AppImage(
                        item.photoUrl!,
                        thumbnail: true,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [gradient.start, gradient.end],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(color: gradient.start.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_isTappable) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
