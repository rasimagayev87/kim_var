import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Small inline badge row for a user's identity-verified/VIP status —
/// same visual language `profile_tab.dart` already used for the
/// signed-in user's own name (verified checkmark, `Icons.
/// verified_outlined` + [AppColors.primary]) plus the VIP crown
/// (`Icons.workspace_premium_outlined` + [AppColors.gold], matching
/// `settings_screen.dart`/`vip_screen.dart`) — made visible next to
/// OTHER users' names too (their profile screen, the chat header),
/// not just on your own profile.
class VerificationBadges extends StatelessWidget {
  final bool identityVerified;
  final bool premium;
  final double size;

  const VerificationBadges({
    super.key,
    required this.identityVerified,
    required this.premium,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (!identityVerified && !premium) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (identityVerified) ...[
          Icon(Icons.verified_outlined, color: AppColors.primary, size: size),
          if (premium) const SizedBox(width: 3),
        ],
        if (premium)
          Icon(
            Icons.workspace_premium_outlined,
            color: AppColors.gold,
            size: size,
          ),
      ],
    );
  }
}
