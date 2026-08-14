import 'package:flutter/material.dart';

/// A hand-picked jewel-tone gradient — deliberately curated rather
/// than generated (e.g. from HSL hue-stepping), so every combination
/// stays legible with a white icon on top and reads as "premium", not
/// as arbitrary/neon. [glow] is the same start color at low alpha,
/// used for the card's own subtle background tint.
class LiveFeedGradient {
  final Color start;
  final Color end;

  const LiveFeedGradient(this.start, this.end);

  Color get glow => start.withValues(alpha: 0.10);
}

/// Ten gradients, built around the app's own cyan brand accent (entry
/// 0) plus nine complementary jewel tones — sapphire/amethyst/emerald/
/// ruby/topaz/coral/indigo/rose/teal — so a feed full of different
/// venues reads as a rich, varied "premium" palette instead of five
/// flat, repeating type colors.
const _liveFeedPalette = <LiveFeedGradient>[
  LiveFeedGradient(Color(0xFF12D6E8), Color(0xFF5EEAF5)), // brand cyan
  LiveFeedGradient(Color(0xFF0EA5E9), Color(0xFF38BDF8)), // sapphire
  LiveFeedGradient(Color(0xFF8B5CF6), Color(0xFFA78BFA)), // amethyst
  LiveFeedGradient(Color(0xFF10B981), Color(0xFF34D399)), // emerald
  LiveFeedGradient(Color(0xFFF43F5E), Color(0xFFFB7185)), // ruby
  LiveFeedGradient(Color(0xFFF59E0B), Color(0xFFFBBF24)), // topaz
  LiveFeedGradient(Color(0xFFFB923C), Color(0xFFFDBA74)), // coral
  LiveFeedGradient(Color(0xFF6366F1), Color(0xFF818CF8)), // indigo
  LiveFeedGradient(Color(0xFFEC4899), Color(0xFFF472B6)), // rose
  LiveFeedGradient(Color(0xFF14B8A6), Color(0xFF2DD4BF)), // teal
];

/// Assigns a stable gradient to [key] (a venueId — every [LiveFeedItem]
/// type carries one, so cards about the same venue always land on the
/// same color across sections/polls, while different venues spread
/// across the whole palette) — deterministic via a small dependency-
/// free djb2-style hash, not [Object.hashCode] (Dart doesn't promise
/// that's stable across app runs, which a "same venue, same color"
/// guarantee needs).
LiveFeedGradient liveFeedGradientForKey(String key) {
  var hash = 5381;
  for (final unit in key.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return _liveFeedPalette[hash % _liveFeedPalette.length];
}
