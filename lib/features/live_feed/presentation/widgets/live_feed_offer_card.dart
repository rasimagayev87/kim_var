import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../offers/domain/entities/offer.dart';
import '../../../offers/presentation/providers/offer_providers.dart';
import '../../../offers/presentation/screens/offer_details_screen.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';

/// Image-top offer card for Canlı's "Yaxınlıqdakı təkliflər" carousel
/// and its "Hamısına bax" full list — deliberately a NEW layout from
/// `_OfferCard` in `offer_list_view.dart` (that one is a left-icon
/// row built around the VENUE's photo; this one is built around the
/// OFFER's own [Offer.imageUrl], which `_OfferCard` never shows at
/// all). [width] null lets the card fill its parent's width (the
/// "Hamısına bax" vertical list); a fixed value sizes it for the
/// horizontal carousel.
class LiveFeedOfferCard extends ConsumerWidget {
  final Offer offer;
  final double distanceMeters;
  final double? width;

  const LiveFeedOfferCard({super.key, required this.offer, required this.distanceMeters, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final distanceUnit = ref.watch(mapLocationSettingsProvider).valueOrNull?.distanceUnit ?? DistanceUnit.km;
    final isFavorite = (ref.watch(favoriteOfferIdsProvider).valueOrNull ?? const {}).contains(offer.id);

    final (badgeColor, badgeText) = switch (offer.offerType) {
      OfferType.discount => (AppColors.primary, '-${offer.discountValue?.round() ?? 0}%'),
      OfferType.fixedPrice => (AppColors.cyanDark, '${offer.discountValue?.round() ?? 0} ₼'),
      OfferType.gift => (const Color(0xFFF5A524), loc.offerBadgeGiftLabel),
      OfferType.buyOneGetOne => (const Color(0xFF7C6CF2), loc.offerBadgeBuyOneGetOneLabel),
      OfferType.happyHour => (const Color(0xFFFF6B6B), '⏰'),
      OfferType.firstVisit => (const Color(0xFF9B59F5), '🎁'),
      OfferType.birthday => (const Color(0xFFFF4FA3), '🎂'),
    };

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: offer.id))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      offer.imageUrl != null
                          ? AppImage(offer.imageUrl!, fit: BoxFit.cover)
                          : Container(color: ChatLightColors.cardSurface, child: const Icon(Icons.local_offer_outlined, color: ChatLightColors.inkSoft)),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Pill(background: badgeColor, child: Text(badgeText, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white))),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _Pill(
                          background: Colors.black.withValues(alpha: 0.55),
                          child: Text(
                            formatDistance(loc, distanceMeters, distanceUnit),
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
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
                      offer.venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ChatLightColors.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 12, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            loc.offerEndsOnLabel(_shortTime(offer.endDate)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: ChatLightColors.inkFaint),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(offerControllerProvider).toggleFavorite(offer.id, isCurrentlyFavorite: isFavorite),
                          child: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_border,
                            size: 17,
                            color: isFavorite ? AppColors.primary : ChatLightColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _Pill extends StatelessWidget {
  final Color background;
  final Widget child;

  const _Pill({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: child,
    );
  }
}
