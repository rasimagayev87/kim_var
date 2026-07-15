import 'package:flutter/material.dart';

class GlowLogo extends StatefulWidget {
  final Widget child;

  const GlowLogo({
    super.key,
    required this.child,
  });

  @override
  State<GlowLogo> createState() => _GlowLogoState();
}

class _GlowLogoState extends State<GlowLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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
      builder: (context, child) {
        final glow = 15 + (_controller.value * 35);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFD5).withOpacity(0.35),
                blurRadius: glow,
                spreadRadius: glow / 8,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}