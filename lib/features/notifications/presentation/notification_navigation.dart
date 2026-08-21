import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/presentation/screens/event_details_screen.dart';
import '../../offers/presentation/providers/offer_providers.dart';
import '../../offers/presentation/screens/create_offer_screen.dart';
import '../../offers/presentation/screens/offer_details_screen.dart';
import '../../pinbox/presentation/providers/pinbox_providers.dart';
import '../../pinbox/presentation/screens/pinbox_checkout_screen.dart';
import '../../post_share/presentation/screens/post_detail_screen.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import '../../profile/presentation/screens/user_profile_screen.dart';
import '../../venues/presentation/screens/venue_profile_screen.dart';
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
Future<void> openNotificationTarget(BuildContext context, WidgetRef ref, AppNotification notification) async {
  final targetId = notification.targetId;
  if (targetId == null) return;

  // Needs an async fetch (the matched venue + uids) before there's
  // anywhere to push to, unlike every other case below — handled
  // first and separately so the switch stays a plain, synchronous
  // `Navigator.push` dispatch for everything else.
  if (notification.targetType == 'birthday_match') {
    if (!ref.read(profileControllerProvider).hasBusinessAccess) return;
    final match = await ref.read(offerRepositoryProvider).fetchBirthdayMatch(targetId);
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(uid: targetId)));
    case 'post':
    case 'comment':
      Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: targetId)));
    case 'venue':
    // "Biznes Təklifi" (venue_offer) has no dedicated Offers screen yet
    // (the Venues module deliberately doesn't fabricate one) — the
    // venue itself is the real, existing destination.
    case 'venue_offer':
      Navigator.push(context, MaterialPageRoute(builder: (_) => VenueProfileScreen(venueId: targetId)));
    // A real offer, not the venue it belongs to — offer moderation
    // decisions (`onOfferUpdated`) and the "new offer near you" fanout
    // (`notifyNearbyUsersOfNewOffer`) both use this.
    case 'offer':
      Navigator.push(context, MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: targetId)));
    // Peak-hour alert (see `computeVenueAudienceHistory`) — the venue
    // owner's actual next step is placing an offer, not just looking
    // at their own venue's profile, so this skips straight to the
    // Create Offer form with the venue already selected.
    case 'venue_create_offer':
      if (ref.read(profileControllerProvider).hasBusinessAccess) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOfferScreen(preselectedVenueId: targetId)));
      }
    // A venue event's own radius-fanout push (`notifyNearbyUsersOfNewEvent`).
    case 'event':
      Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: targetId)));
    // PinBox moderation decisions (`onPinBoxUpdated`) and the "new box
    // near you" fanout (`notifyNearbyUsersOfNewPinBox`) both target the
    // box itself — needs an async fetch first, same as birthday_match
    // above, but small enough to stay inline here since this function
    // is already async.
    case 'pinbox':
      final pinbox = await ref.read(pinboxByIdProvider(targetId).future);
      if (!context.mounted || pinbox == null) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PinBoxCheckoutScreen(pinbox: pinbox)));
  }
}
