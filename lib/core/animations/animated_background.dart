import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
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
      builder: (_, __) {
        return CustomPaint(
          painter: _BackgroundPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t;

  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF011715),
          Color(0xFF003C33),
          Color(0xFF011715),
        ],
        stops: [
          0,
          .5 + (.08 * sin(t * pi)),
          1,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, gradient);

    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 150);

    glow.color = const Color(0x3300FFD0);

    canvas.drawCircle(
      Offset(
        size.width * (.18 + .06 * sin(t * pi * 2)),
        size.height * .28,
      ),
      170,
      glow,
    );

    canvas.drawCircle(
      Offset(
        size.width * (.82 - .05 * sin(t * pi * 2)),
        size.height * .74,
      ),
      210,
      glow,
    );

    final line = Paint()
      ..color = const Color(0x2200FFD0)
      ..strokeWidth = 1;

    final random = Random(8);

    for (int i = 0; i < 45; i++) {
      final p1 = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      final p2 = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      canvas.drawLine(p1, p2, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}