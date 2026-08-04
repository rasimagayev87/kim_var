import 'package:flutter/material.dart';

import '../../post_share/presentation/screens/post_detail_screen.dart';
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
void openNotificationTarget(BuildContext context, AppNotification notification) {
  final targetId = notification.targetId;
  if (targetId == null) return;

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
  }
}
