import 'dart:async';

import 'package:flutter/material.dart';

/// Auto-scrolls [text] horizontally when it doesn't fit the available
/// width, instead of truncating it with an ellipsis — used where the
/// hidden tail actually matters (e.g. a chat header's
/// "@handle · Son görülmə: X" status line, where an ellipsis can hide
/// the last-seen time entirely). Renders as a plain, static
/// (ellipsis-truncated) [Text] when [text] already fits — no
/// animation overhead for the common case.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final Duration scrollDuration;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.scrollDuration = const Duration(seconds: 4),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _scrollController = ScrollController();
  Timer? _pauseTimer;
  bool _forward = true;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
      _forward = true;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startCycle() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _pauseTimer = Timer(widget.pauseDuration, () async {
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        _forward ? maxExtent : 0,
        duration: widget.scrollDuration,
        curve: Curves.linear,
      );
      _forward = !_forward;
      _startCycle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        if (textPainter.width <= constraints.maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        if (_pauseTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startCycle());
        }

        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}
