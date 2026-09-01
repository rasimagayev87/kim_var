import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../pinbox/domain/entities/pinbox.dart';
import '../../../pinbox/presentation/screens/pinbox_checkout_screen.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';

/// A listing is "Yeni" for the same 24h window `liveFeedFreshWindow`
/// already uses to mark an offer fresh in the old Canlı feed — reusing
/// that established threshold rather than inventing a new one.
const _kFreshWindow = Duration(hours: 24);

/// Image-top PinBox card for Canlı's "PinBox elanları" carousel and
/// its "Hamısına bax" full list. Deliberately does NOT include an
/// owner "..." options menu — no such widget/action exists anywhere
/// else for PinBox (unlike posts, which have `PostOwnerMenuButton`),
/// and this pass is visual-only, not a new-functionality pass. Tapping
/// the card goes straight to [PinBoxCheckoutScreen], same as every
/// other PinBox card in the app — there's no separate details screen.
class LiveFeedPinboxCard extends ConsumerWidget {
  final PinBox pinbox;
  final double distanceMeters;
  final double? width;

  const LiveFeedPinboxCard({
    super.key,
    required this.pinbox,
    required this.distanceMeters,
    this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final distanceUnit =
        ref.watch(mapLocationSettingsProvider).valueOrNull?.distanceUnit ??
        DistanceUnit.km;
    final isNew = DateTime.now().difference(pinbox.createdAt) < _kFreshWindow;
    final isSoldOut = pinbox.isSoldOut;

    return SizedBox(
      width: width,
      child: Opacity(
        opacity: isSoldOut ? 0.55 : 1,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PinBoxCheckoutScreen(pinbox: pinbox),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        pinbox.imageUrl != null
                            ? AppImage(pinbox.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: ChatLightColors.cardSurface,
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: ChatLightColors.inkSoft,
                                ),
                              ),
                        if (isNew && !isSoldOut)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                loc.liveFeedNewBadge,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (isSoldOut)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                loc.pinboxSoldOutLabel,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pinbox.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ChatLightColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pinbox.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ChatLightColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${pinbox.originalPrice.toStringAsFixed(0)} ₼',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ChatLightColors.inkFaint,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${pinbox.pinboxPrice.toStringAsFixed(0)} ₼',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatRelativeTime(pinbox.createdAt, loc)} · ${formatDistance(loc, distanceMeters, distanceUnit)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ChatLightColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
