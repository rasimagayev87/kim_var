import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/animations/animated_background.dart';
import '../../../../core/animations/glow_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/screens/phone_auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  GlowLogo(
                    child: Image.asset(
                      'assets/icon_foreground.png',
                      width: 220,
                      height: 220,
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                      ),
                  const SizedBox(height: 22),
                  const Text(
                    'Ətrafındakı insanları kəşf et,\nyeni tanışlıqlar və dostluqlar qur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
                  const Spacer(flex: 4),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                    ),
                    child: const Text('Başla'),
                  ).animate().fadeIn(delay: 450.ms, duration: 450.ms).slideY(
                        begin: 0.2,
                        end: 0,
                      ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
