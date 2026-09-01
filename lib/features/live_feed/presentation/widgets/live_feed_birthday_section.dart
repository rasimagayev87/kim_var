import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/providers/venue_providers.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart'
    show venueCategoryLabel;
import '../../../venues/presentation/screens/venue_profile_screen.dart';
import '../providers/birthday_feed_providers.dart';
import '../screens/birthday_opportunities_screen.dart';
import 'live_feed_section_header.dart';

const double _kCardWidth = 160;

/// Birthday pink — the same colour `LiveFeedOfferCard` already gives
/// `OfferType.birthday`, so the section and the cards inside the offers
/// carousel read as one thing rather than two features that happen to
/// share a cake icon.
const Color kBirthdayAccent = Color(0xFFFF4FA3);

/// "Ad günü fürsətləri" — the 13:00 publication, and the ONLY Canlı
/// section that is not there for most people most of the time.
///
/// Renders exactly when [myBirthdayFeedProvider] returns a document,
/// which the server writes only for someone whose birthday is today and
/// only when at least one venue actually published a campaign for them.
/// There is no local birthday check and no empty state: a birthday
/// greeting attached to nothing at all is worse than silence, so zero
/// campaigns means the section is absent, not empty.
class LiveFeedBirthdaySection extends ConsumerWidget {
  const LiveFeedBirthdaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final feedAsync = ref.watch(myBirthdayFeedProvider);

    return feedAsync.when(
      data: (feed) {
        if (feed == null || feed.isEmpty) return const SizedBox.shrink();
        final ids = feed.venueIds.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LiveFeedSectionHeader(
                icon: Icons.cake_rounded,
                iconColor: kBirthdayAccent,
                title: loc.birthdaySectionTitle,
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BirthdayOpportunitiesScreen(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(
                loc.birthdaySectionSubtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ChatLightColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ids.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    BirthdayVenueCard(venueId: ids[index], width: _kCardWidth),
              ),
            ),
            // The gap to the next section belongs to THIS widget, not
            // to `live_feed_screen.dart` — the section renders nothing
            // on 364 days out of 365, and a `SizedBox` left behind in
            // the parent would leave a hole on every one of them.
            const SizedBox(height: 24),
          ],
        );
      },
      // A birthday section that flickers a spinner into the middle of
      // the Canlı feed for everyone, one day a year, is worse than one
      // that simply appears when it has something to show.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// One venue from the birthday feed. Resolves the venue by id because
/// `birthdayFeed` stores ids only — the campaign's own details live on
/// the offer, which the venue profile already shows.
class BirthdayVenueCard extends ConsumerWidget {
  const BirthdayVenueCard({super.key, required this.venueId, this.width});

  final String venueId;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final venue = ref.watch(venueByIdProvider(venueId)).valueOrNull;
    if (venue == null) return SizedBox(width: width);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VenueProfileScreen(venueId: venueId),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      venue.photoUrl != null
                          ? AppImage(venue.photoUrl!, fit: BoxFit.cover)
                          : Container(
                              color: ChatLightColors.cardSurface,
                              child: Icon(
                                venueCategoryIcon(venue.category),
                                color: ChatLightColors.inkSoft,
                              ),
                            ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kBirthdayAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '🎂',
                            style: TextStyle(fontSize: 11, height: 1.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ChatLightColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      venueCategoryLabel(loc, venue.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ChatLightColors.inkSoft,
                      ),
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
}
