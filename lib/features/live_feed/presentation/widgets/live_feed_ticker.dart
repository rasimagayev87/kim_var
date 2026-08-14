import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/live_feed_item.dart';
import 'live_feed_palette.dart';

/// Constantly-scrolling news-ticker bar pinned above the card list —
/// generated from the last few real [LiveFeedItem]s (never static
/// copy), each rendered as "[colored dot] [title] — [subtitle]" per
/// the spec. Dependency-free: a plain [Ticker] nudging a
/// [ScrollController] every frame, wrapping the content twice so the
/// loop point isn't visible.
class LiveFeedTicker extends StatefulWidget {
  final List<LiveFeedItem> items;

  const LiveFeedTicker({super.key, required this.items});

  @override
  State<LiveFeedTicker> createState() => _LiveFeedTickerState();
}

class _LiveFeedTickerState extends State<LiveFeedTicker> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _scrollController = ScrollController();

  /// Px/sec — slow enough to read comfortably.
  static const _speed = 28.0;

  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    final position = _scrollController.position;
    // Half of maxScrollExtent, since the content is duplicated once —
    // resetting there (not at the true end) is what makes the loop
    // point invisible: the second copy is already in the exact place
    // the first copy started from.
    final loopAt = position.maxScrollExtent / 2;
    if (loopAt <= 0) return;

    var next = position.pixels + _speed * dt;
    if (next >= loopAt) next -= loopAt;
    _scrollController.jumpTo(next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    // Last 3-5 items, most-recent-first list reversed so the ticker
    // reads oldest-of-the-recent-batch first, most recent last —
    // matches how a news ticker's own "latest at the tail" convention
    // reads, rather than restarting on the newest item every scroll.
    final recent = widget.items.take(5).toList().reversed.toList();

    return Container(
      height: 34,
      color: const Color(0xFF111827),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            _TickerLine(items: recent),
            _TickerLine(items: recent),
          ],
        ),
      ),
    );
  }
}

class _TickerLine extends StatelessWidget {
  final List<LiveFeedItem> items;

  const _TickerLine({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) ...[
            _TickerDot(venueId: item.venueId),
            const SizedBox(width: 8),
            Text(
              '${item.title} — ${item.subtitle}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 28),
          ],
        ],
      ),
    );
  }
}

class _TickerDot extends StatelessWidget {
  final String venueId;

  const _TickerDot({required this.venueId});

  @override
  Widget build(BuildContext context) {
    final gradient = liveFeedGradientForKey(venueId);
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: gradient.start, shape: BoxShape.circle),
    );
  }
}
