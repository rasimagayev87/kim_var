import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../privacy/presentation/providers/privacy_providers.dart';
import '../providers/auth_providers.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

const _kPendingEmailLinkAddressKey = 'pendingEmailLinkAddress';

/// Pushed by `deep_link_handler.dart` when the app is opened via a
/// Firebase email sign-in link — the actual work happens here (not in
/// the handler itself) purely to get a [WidgetRef]: the handler runs
/// outside the widget tree, this screen doesn't.
class EmailLinkSignInScreen extends ConsumerStatefulWidget {
  final String link;

  const EmailLinkSignInScreen({super.key, required this.link});

  @override
  ConsumerState<EmailLinkSignInScreen> createState() => _EmailLinkSignInScreenState();
}

class _EmailLinkSignInScreenState extends ConsumerState<EmailLinkSignInScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    // Signed in AND profile already complete is the account-deletion
    // reauth flow (see `DeleteAccountRow._ReauthSheet`) reusing the
    // same email-link mechanism — complete that instead of starting a
    // fresh sign-in. A signed-in user with an INCOMPLETE profile can
    // legitimately hit this same link too (resuming onboarding after
    // the app was closed mid-signup, see `SplashScreen`) — that case
    // must fall through to the normal sign-in-link handling below,
    // not be mistaken for a reauth.
    final authController = ref.read(authControllerProvider.notifier);
    if (fb.FirebaseAuth.instance.currentUser != null && !authController.needsOnboarding) {
      try {
        await ref.read(accountControllerProvider).reauthenticateWithEmailLink(widget.link);
      } catch (_) {
        // Swallowed — the reauth sheet is still open and waiting; the
        // user can just try again from there.
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kPendingEmailLinkAddressKey);
    if (email == null) {
      // Link opened on a different device/browser than the one that
      // requested it — Firebase's own documented edge case for this
      // flow. Nothing to recover automatically; send them back to
      // start a fresh sign-in.
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
      return;
    }

    try {
      final (_, isNewUser) = await ref
          .read(authControllerProvider.notifier)
          .signInWithEmailLink(email: email, link: widget.link);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNewUser ? const OnboardingScreen() : const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(loc.authSigningInMessage, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
