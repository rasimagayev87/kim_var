import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/deep_link_handler.dart' show navigatorKey;
import 'app_logger.dart';

/// Call from the catch block of a background Firestore write (presence
/// heartbeat, live location) when it fails with `permission-denied`, to
/// tell a genuinely deleted/banned account apart from a routine,
/// transient failure — a race right after sign-in/sign-out, or a rules
/// change not yet deployed (see `firestore_retry.dart`'s own handling
/// of that same error code) — and force a clean sign-out only for the
/// former.
///
/// `Auth.currentUser.reload()` is what makes the distinction: it throws
/// `user-disabled`/`user-not-found` when the account is genuinely gone,
/// but succeeds (silently) when the Auth account is still healthy and
/// the `permission-denied` was something else entirely — that's the
/// case this deliberately does NOT sign the user out for.
///
/// Returns `true` if the account was confirmed gone/disabled — the
/// caller should stop whatever timer/subscription triggered the write
/// (no point retrying a write that will never succeed again).
Future<bool> handleWritePermissionDenied(Object error, {fb.FirebaseAuth? auth}) async {
  if (!isPermissionDeniedError(error)) return false;

  final firebaseAuth = auth ?? fb.FirebaseAuth.instance;
  final user = firebaseAuth.currentUser;
  if (user == null) return false;

  try {
    await user.reload();
    // Auth account is still healthy — a transient/race permission-denied,
    // not a real deletion/ban. Don't force a sign-out for this.
    return false;
  } on fb.FirebaseAuthException catch (e) {
    if (e.code != 'user-disabled' && e.code != 'user-not-found') return false;
  } catch (_) {
    return false;
  }

  await firebaseAuth.signOut();

  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
    // Posted a frame later — right after `pushAndRemoveUntil`, the
    // Navigator hasn't finished rebuilding yet, and `navigatorKey
    // .currentContext` at that instant can still point at the screen
    // that's about to be removed rather than one with a live
    // ScaffoldMessenger ancestor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final freshContext = navigatorKey.currentContext;
      if (freshContext == null || !freshContext.mounted) return;
      final loc = AppLocalizations.of(freshContext);
      ScaffoldMessenger.of(freshContext).showSnackBar(
        SnackBar(content: Text(loc.accountDisabledMessage), duration: const Duration(seconds: 6)),
      );
    });
  }
  return true;
}
