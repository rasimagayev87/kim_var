import 'package:flutter/material.dart';

/// Immediate press feedback for a tap target, without the Material
/// ripple.
///
/// `AppTheme` deliberately disables the stock ripple
/// (`splashFactory: NoSplash`, transparent splash/highlight) so the app
/// does not read as generic Android. Its comment says controls "rely on
/// our own state styling instead" — but that styling was never built,
/// so most taps produced NO feedback at all. A tap that starts a
/// half-second network call looked identical to a tap that missed, and
/// people pressed again.
///
/// This is the missing half: the control dims and shrinks the instant a
/// finger lands, and springs back on release. It costs nothing (no
/// layout, no repaint of anything but this subtree), it is identical on
/// iOS and Android — unlike the ripple, which is a platform tell — and
/// it happens BEFORE any work starts, so a slow action still feels
/// acknowledged.
///
/// Deliberately opt-in per call site rather than a global wrapper:
/// controls with their own gesture semantics (the chat mic button's
/// long-press-and-drag recording, message bubbles with context menus)
/// must not have a competing detector layered on them.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it shrinks. Small on purpose — this should register as
  /// responsiveness, not as an animation someone has to wait for.
  final double pressedScale;

  /// How much it dims.
  final double pressedOpacity;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.pressedOpacity = 0.6,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // A disabled target must not appear to react — pretending a tap
    // registered when nothing will happen is worse than no feedback.
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        // Fast down, so the feedback is felt as instant; the same
        // duration back up reads as a spring rather than a fade.
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}
