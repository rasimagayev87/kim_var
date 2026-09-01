import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown in place of a missing profile photo — a subtle diagonal-stripe
/// watermark over the app's dark palette, rather than a flat gray tile
/// with a single centered icon. Shared between the discover card stack
/// and the user profile screen so both read as the same design.
class PhotoPlaceholderPattern extends StatelessWidget {
  const PhotoPlaceholderPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.cardOverlay),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DiagonalPatternPainter()),
          Center(
            child: Icon(
              Icons.person_rounded,
              size: 88,
              color: Color(0x1AFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalPatternPainter extends CustomPainter {
  const _DiagonalPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1.4;
    const spacing = 18.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalPatternPainter oldDelegate) => false;
}
