import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/providers/home_tab_providers.dart';
import '../../events/presentation/screens/event_details_screen.dart';
import '../../offers/presentation/providers/offer_providers.dart';
import '../../offers/presentation/screens/create_offer_screen.dart';
import '../../offers/presentation/screens/offer_details_screen.dart';
import '../../pinbox/presentation/providers/pinbox_providers.dart';
import '../../pinbox/presentation/screens/pinbox_checkout_screen.dart';
import '../../pinbox/presentation/screens/pinbox_ticket_screen.dart';
import '../../post_share/presentation/screens/post_detail_screen.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import '../../profile/presentation/screens/user_profile_screen.dart';
import '../../venues/presentation/providers/venue_providers.dart';
import '../../live_feed/presentation/screens/birthday_opportunities_screen.dart';
import '../../venues/presentation/screens/my_venues_screen.dart';
import '../../venues/presentation/screens/venue_profile_screen.dart';
import '../../waitlist/presentation/screens/venue_waitlist_screen.dart';
import '../domain/entities/notification.dart';

/// Routes a tapped [AppNotification] to its real destination screen,
/// based on [AppNotification.targetType]/[AppNotification.targetId].
///
/// [AppNotification.deepLink] is reserved for a future URL-based
/// router — this app navigates via direct [MaterialPageRoute] pushes
/// everywhere else, so there's no route table to resolve a path string
/// against yet. Building one just for this field would be exactly the
/// kind of speculative abstraction this codebase avoids; targetType +
/// targetId already covers every destination this module produces
/// today, and a type this build doesn't recognize simply does nothing
/// on tap rather than crashing.
Future<void> openNotificationTarget(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) async {
  // Handled BEFORE the `targetId` guard, because this is the one
  // notification that legitimately has none.
  //
  // The daily digest ("Ətrafında 5 yeni kampaniya…") summarises many
  // listings, so there is no single document to open — the destination
  // is the Canlı tab, where all three content kinds live. Every other
  // type names one document and falls through to the switch below.
  if (notification.targetType == 'live_feed') {
    ref.read(requestedHomeTabProvider.notifier).state = HomeTab.live;
    // Pops any detail route the user opened on top of HomeScreen, so
    // the tab switch is actually visible rather than happening behind
    // whatever is on screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    return;
  }

  final targetId = notification.targetId;
  if (targetId == null) return;

  // Needs an async fetch (the matched venue + uids) before there's
  // anywhere to push to, unlike every other case below — handled
  // first and separately so the switch stays a plain, synchronous
  // `Navigator.push` dispatch for everything else.
  if (notification.targetType == 'birthday_match') {
    if (!ref.read(profileControllerProvider).hasBusinessAccess) return;
    final match = await ref
        .read(offerRepositoryProvider)
        .fetchBirthdayMatch(targetId);
    if (match == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOfferScreen(
          preselectedVenueId: match.venueId,
          birthdayMatchId: targetId,
          birthdayTargetUserIds: match.matchedUserIds,
        ),
      ),
    );
    return;
  }

  switch (notification.targetType) {
    case 'profile':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(uid: targetId)),
      );
    case 'post':
    case 'comment':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: targetId)),
      );
    case 'venue':
    // "Biznes Təklifi" (venue_offer) has no dedicated Offers screen yet
    // (the Venues module deliberately doesn't fabricate one) — the
    // venue itself is the real, existing destination.
    case 'venue_offer':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VenueProfileScreen(venueId: targetId),
        ),
      );
    // A real offer, not the venue it belongs to — offer moderation
    // decisions (`onOfferUpdated`) and the "new offer near you" fanout
    // (`notifyNearbyUsersOfNewOffer`) both use this.
    case 'offer':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfferDetailsScreen(offerId: targetId),
        ),
      );
    // Peak-hour alert (see `computeVenueAudienceHistory`) — the venue
    // owner's actual next step is placing an offer, not just looking
    // at their own venue's profile, so this skips straight to the
    // Create Offer form with the venue already selected.
    case 'venue_create_offer':
      if (ref.read(profileControllerProvider).hasBusinessAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateOfferScreen(preselectedVenueId: targetId),
          ),
        );
      }
    // A venue event's own radius-fanout push (`notifyNearbyUsersOfNewEvent`).
    case 'event':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(eventId: targetId),
        ),
      );
    // PinBox moderation decisions (`onPinBoxUpdated`) and the "new box
    // near you" fanout (`notifyNearbyUsersOfNewPinBox`) both target the
    // box itself — needs an async fetch first, same as birthday_match
    // above, but small enough to stay inline here since this function
    // is already async.
    case 'pinbox':
      final pinbox = await ref.read(pinboxByIdProvider(targetId).future);
      if (!context.mounted || pinbox == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinBoxCheckoutScreen(pinbox: pinbox)),
      );
    // Overdue subscription cycle (`renewVenueSubscriptions`) — the
    // owner's own venue list shows the "Ödə" banner on whichever
    // venue(s) are actually overdue, no need to single one out here.
    case 'venue_subscription_due':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyVenuesScreen()),
      );
    // The 11:00 birthday nudge when the owner has SEVERAL matched
    // venues — there is no single `birthdayMatches` doc to pre-fill
    // Create Offer with, so this lands on the venue list and the owner
    // picks. With one venue it takes the `birthday_match` branch above
    // and goes straight into the pre-filled flow instead.
    case 'my_venues':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyVenuesScreen()),
      );
    // The 13:00 birthday publication. Names up to three venues but
    // opens the full list — several campaigns arrive at the same
    // moment, which is the whole point of publishing them together.
    case 'birthday_feed':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BirthdayOpportunitiesScreen()),
      );
    // A confirmed PinBox order — buyer's own ticket, same destination
    // `_OrderCard` itself navigates to from "Aldıqlarım".
    case 'pinbox_order':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinBoxTicketScreen(orderId: targetId),
        ),
      );
  }

  // A customer joined this venue's waitlist (`joinWaitlist`) — skips
  // straight to VenueWaitlistScreen (not just the venue profile) so
  // the owner can call/seat the new entry immediately. Needs an async
  // fetch first (VenueWaitlistScreen takes a full Venue, not just an
  // id), same shape as `pinbox`/`birthday_match` above — kept outside
  // the switch for the same reason those two are.
  if (notification.targetType == 'venue_waitlist') {
    final venue = await ref.read(venueByIdProvider(targetId).future);
    if (venue == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VenueWaitlistScreen(venue: venue)),
    );
  }
}
