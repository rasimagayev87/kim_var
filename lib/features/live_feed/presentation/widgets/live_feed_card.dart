import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/live_feed_item.dart';

/// Per-type icon + accent color — see this widget's own doc comment
/// for why [LiveFeedType.offer] uses green despite the rest of the app
/// having deliberately moved off green in favor of the cyan brand
/// accent: flag this to the user rather than silently picking
/// something else, since it's their own explicit spec value.
(IconData, Color) iconAndColorForLiveFeedType(LiveFeedType type) {
  return switch (type) {
    LiveFeedType.audience => (Icons.groups_rounded, const Color(0xFFF31260)),
    LiveFeedType.event => (Icons.celebration_rounded, AppColors.primary),
    LiveFeedType.offer => (Icons.local_offer_rounded, const Color(0xFF18C964)),
    LiveFeedType.seatAvailable => (Icons.event_seat_rounded, AppColors.primary),
    LiveFeedType.birthday => (Icons.cake_rounded, const Color(0xFFF5A524)),
  };
}

/// One row in the Canlı card list — exact shape from the spec: 34x34
/// rounded-square icon container, title/subtitle, trailing chevron.
/// Colors: card/background/text roles reuse the app's own [AppColors]
/// (the closest existing named constants to the spec's literal hex
/// values — e.g. `AppColors.background` is 0xFFEEF1F4 against the
/// spec's 0xFFF4F6F8, a one-character difference); the icon container
/// fill and per-type accent colors above are local literals (same
/// "inline per-type Color, not a shared named constant" convention
/// `offer_list_view.dart`'s own type-badge colors already use in this
/// codebase), since no existing named constant matches them closely
/// enough to reuse.
class LiveFeedCard extends StatelessWidget {
  final LiveFeedItem item;
  final VoidCallback onTap;

  const LiveFeedCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = iconAndColorForLiveFeedType(item.type);

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F4),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
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
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
