import 'package:flutter/material.dart';

import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// "Title" + "Hamısına bax ›" row shared by every Canlı section
/// ([LiveFeedOfferCard]'s "Yaxınlıqdakı təkliflər" and friends) — kept
/// as one widget so the row's spacing/typography can't quietly drift
/// between sections.
class LiveFeedSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onSeeAll;

  const LiveFeedSectionHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: ChatLightColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.liveFeedSeeAll,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
                ),
                const Icon(Icons.chevron_right, size: 18, color: ChatLightColors.inkSoft),
              ],
            ),
          ),
      ],
    );
  }
}
