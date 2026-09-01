import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/post_share/presentation/screens/post_detail_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../utils/app_logger.dart';

/// App-wide navigator key so incoming deep links can push a screen
/// without needing a [BuildContext] from inside the widget tree — set
/// as [MaterialApp.navigatorKey] in `main.dart`.
final navigatorKey = GlobalKey<NavigatorState>();

/// Starts listening for incoming Universal Links (iOS)/App Links
/// (Android) — `https://peakpin.app/p/{postId}` (Instagram's own
/// `/p/` convention — see peakpin-landing's `/p/[postId]` route,
/// which is the same URL this deep link intercepts before it ever
/// reaches a browser) — and pushes [PostDetailScreen] for the
/// matching post. Call once from `main()` after `runApp`; safe to
/// call even before the navigator has attached its first frame, since
/// [AppLinks] buffers the launch link until a listener is attached.
void startDeepLinkListener() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen(
    _handleUri,
    onError: (e, st) {
      logError('deep_link_handler.startDeepLinkListener', e, st);
    },
  );
}

void _handleUri(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[0] == 'p') {
    final postId = segments[1];
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
    return;
  }

  if (segments.length >= 2 && segments[0] == 'u') {
    _openProfileByUsername(segments[1]);
    return;
  }

  // `peakpin://u/{username}` — the custom-scheme "PeakPin-də aç" button
  // on the /u/{username} web fallback page. A custom scheme puts the
  // first path component in [Uri.host], not [Uri.pathSegments] (unlike
  // the https form above), since there's no real authority to parse —
  // handled separately here rather than folding into the https check.
  if (uri.scheme == 'peakpin' && uri.host == 'u' && segments.isNotEmpty) {
    _openProfileByUsername(segments[0]);
    return;
  }

  // No recognized pattern (a future link shape this build predates,
  // or a genuinely malformed one) — land on the home screen rather
  // than silently doing nothing, so the tap that brought the user
  // here doesn't feel like it went nowhere. `pushReplacement` (not
  // `push`) so this doesn't stack underneath whatever screen happened
  // to be open when the link arrived.
  final navigator = navigatorKey.currentState;
  if (navigator != null && navigator.mounted) {
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}

/// Resolves `https://peakpin.app/u/{username}` the same way the
/// registration flow checks username availability — a direct doc get
/// on the `usernames/{lowercaseUsername}` reservation collection
/// (`FirebaseAuthRepository`'s own lookup pattern) — rather than a
/// `where` query, since [UserProfileScreen] needs a uid, not a
/// username. Silently no-ops on a stale/mistyped link; there's no
/// screen worth showing for "this username doesn't exist".
Future<void> _openProfileByUsername(String username) async {
  try {
    final reservation = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    final uid = reservation.data()?['uid'] as String?;
    if (uid == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(uid: uid)),
    );
  } catch (e, st) {
    logError('deep_link_handler._openProfileByUsername', e, st);
  }
}

/// Starts listening for Branch (branch.io) session data — covers the
/// case [startDeepLinkListener] can't: a user who didn't have the app
/// installed yet. peakpin-landing generates Branch links (instead of
/// plain `https://peakpin.app/p/{id}` links) for its "open app" CTAs,
/// carrying the post id as custom data. Branch stores that on click
/// and hands it back here on the app's first open after install
/// (deferred deep link), or immediately if the app was already
/// installed. Call once from `main()`, after [FlutterBranchSdk.init].
void startBranchDeepLinkListener() {
  FlutterBranchSdk.listSession().listen(
    (data) {
      if (data['+clicked_branch_link'] != true) return;
      final postId = data['postId'] as String?;
      if (postId == null || postId.isEmpty) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
      );
    },
    onError: (e, st) {
      logError('deep_link_handler.startBranchDeepLinkListener', e, st);
    },
  );
}
