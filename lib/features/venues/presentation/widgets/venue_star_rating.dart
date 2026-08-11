import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// 5-star row for [Venue.rating] (0-5, one decimal) — full/half/empty
/// stars sized to the nearest half-star below the actual value (never
/// rounds UP, so the stars never overpromise relative to the number
/// shown next to them).
class VenueStarRating extends StatelessWidget {
  final double rating;
  final double size;

  const VenueStarRating({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final halfSteps = (rating * 2).floor().clamp(0, 10);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final stepsForThisStar = halfSteps - i * 2;
        final IconData icon;
        if (stepsForThisStar >= 2) {
          icon = Icons.star_rounded;
        } else if (stepsForThisStar == 1) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: AppColors.gold);
      }),
    );
  }
}

/// [VenueStarRating] plus the numeric value (e.g. "4.7") — the
/// combination shown on both the venue card and the profile header.
class VenueRatingBadge extends StatelessWidget {
  final double rating;
  final double starSize;
  final TextStyle? textStyle;

  const VenueRatingBadge({
    super.key,
    required this.rating,
    this.starSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VenueStarRating(rating: rating, size: starSize),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style:
              textStyle ??
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
