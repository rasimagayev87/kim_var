import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import '../../features/auth/presentation/screens/email_link_sign_in_screen.dart';
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
  appLinks.uriLinkStream.listen(_handleUri, onError: (e, st) {
    logError('deep_link_handler.startDeepLinkListener', e, st);
  });
}

void _handleUri(Uri uri) {
  // Firebase's own email sign-in link — see `AuthRepository.
  // sendEmailSignInLink`'s doc comment for why this rides the same
  // Universal Link infrastructure as `/p/{postId}` below, rather than
  // needing a separate Dynamic Links setup.
  if (fb.FirebaseAuth.instance.isSignInWithEmailLink(uri.toString())) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => EmailLinkSignInScreen(link: uri.toString())),
    );
    return;
  }

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
    final reservation = await FirebaseFirestore.instance.collection('usernames').doc(username.toLowerCase()).get();
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
  FlutterBranchSdk.listSession().listen((data) {
    if (data['+clicked_branch_link'] != true) return;
    final postId = data['postId'] as String?;
    if (postId == null || postId.isEmpty) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }, onError: (e, st) {
    logError('deep_link_handler.startBranchDeepLinkListener', e, st);
  });
}
