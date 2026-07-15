import 'dart:math';
import 'package:flutter/material.dart';

class MovingPeople extends StatefulWidget {
  const MovingPeople({super.key});

  @override
  State<MovingPeople> createState() => _MovingPeopleState();
}

class _MovingPeopleState extends State<MovingPeople>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PeoplePainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PeoplePainter extends CustomPainter {
  final double progress;

  _PeoplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = const Color(0xFF00FFD5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (int i = 0; i < 24; i++) {
      final angle = (2 * pi / 24) * i;

      final startRadius = size.width * 0.75;
      final endRadius = 40.0;

      final radius =
          startRadius - (startRadius - endRadius) * progress;

      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}