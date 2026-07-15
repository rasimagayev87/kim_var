import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/onboarding_screen.dart';
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

    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return; // still restoring session, wait

    _navigated = true;
    final controller = ref.read(authControllerProvider.notifier);
    final user = authState.valueOrNull;

    Widget destination;
    if (user != null) {
      destination = const HomeScreen();
    } else if (controller.needsOnboarding) {
      destination = const OnboardingScreen();
    } else {
      destination = const WelcomeScreen();
    }

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

    return const Scaffold(
      body: AnimatedBackground(),
    );
  }
}
