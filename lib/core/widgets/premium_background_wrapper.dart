import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's single ambient background — mounted once in
/// `PeakPinApp.builder` (main.dart), behind the whole Navigator, so it
/// never rebuilds or seams between screens. Individual screens show it
/// through by leaving their own `Scaffold.backgroundColor` transparent
/// rather than painting their own opaque background — see
/// `AppColors.background`'s doc comment for why the old flat color is
/// still kept around as a token (some non-Scaffold surfaces still use
/// it deliberately, e.g. dialogs).
class PremiumBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const PremiumBackgroundWrapper({super.key, required this.child});

  static const _base = Color(0xFFF8FAFC);
  static const _coolGlow = Color(0xFF00B4C6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(color: _base),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_coolGlow.withValues(alpha: 0.05), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
