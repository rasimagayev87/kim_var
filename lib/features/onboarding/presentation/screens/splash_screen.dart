import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../app_config/domain/entities/app_config.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../app_config/presentation/screens/force_update_screen.dart';
import '../../../app_config/presentation/screens/maintenance_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'welcome_screen.dart';

/// A brief, functional splash — just long enough to check whether
/// a session already exists so we can route straight to the right
/// place (no decorative delay).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _tryNavigate() {
    if (_navigated) return;

    // Read-only from whatever's already cached — never blocks on a
    // network fetch (see RemoteConfigDataSource.init()'s own doc
    // comment for why this is safe to check unconditionally here).
    final config = ref.read(appConfigProvider);
    if (config.maintenanceModeEnabled) {
      _navigated = true;
      _push(const MaintenanceScreen());
      return;
    }
    if (ref.read(updateStatusProvider) == UpdateStatus.forceUpdateRequired) {
      _navigated = true;
      _push(const ForceUpdateScreen());
      return;
    }

    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return; // still restoring session, wait

    _navigated = true;
    final user = authState.valueOrNull;

    // A signed-in-but-incomplete-profile session (`needsOnboarding`)
    // deliberately does NOT route straight to OnboardingScreen here —
    // it goes through WelcomeScreen/AuthScreen like any other
    // unauthenticated cold start. Landing on Onboarding again is the
    // natural result of _that_ sign-in succeeding (see AuthScreen,
    // which already routes to Onboarding vs Home based on the
    // sign-in result's `isNewUser`) — not something this splash check
    // should short-circuit into.
    final destination = user != null
        ? const HomeScreen()
        : const WelcomeScreen();
    _push(destination);
  }

  void _push(Widget destination) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (!next.isLoading) _tryNavigate();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigate());

    return const Scaffold(body: AnimatedBackground());
  }
}
