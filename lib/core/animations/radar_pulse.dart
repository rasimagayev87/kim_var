import 'package:flutter/material.dart';

/// Concentric rings that continuously expand outward and fade —
/// evokes a location "ping", reinforcing the geolocation concept
/// behind the app while the logo forms in the center.
class RadarPulse extends StatefulWidget {
  final Widget child;
  final double maxRadius;
  final Color color;

  const RadarPulse({
    super.key,
    required this.child,
    this.maxRadius = 170,
    this.color = const Color(0xFF00FFD5),
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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
          painter: _RadarPainter(
            t: _controller.value,
            maxRadius: widget.maxRadius,
            color: widget.color,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final double maxRadius;
  final Color color;

  _RadarPainter({required this.t, required this.maxRadius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final phase = (t + i / ringCount) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1 - phase).clamp(0.0, 1.0) * 0.45;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
