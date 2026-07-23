import 'package:flutter/material.dart';

/// Premium light "Meevima" design system — the same open, airy palette
/// the chat/profile screens established (`ChatLightColors`), now the
/// app-wide default. Field names are kept stable across the old dark
/// palette on purpose — hundreds of call sites reference
/// `AppColors.primary`, `.background`, `.card` etc., so re-pointing the
/// same tokens to new values is what lets the rebrand cascade through
/// `ThemeData` without touching every screen. One consequence of that:
/// [white] now holds a dark ink value (it used to BE white) — the name
/// stayed put so hundreds of `color: AppColors.white` call sites (most
/// of them "the primary text/icon color") didn't all need editing.
class AppColors {
  /// Primary Background — the scaffold base, lightest tier.
  static const Color background = Color(0xFFEEF1F4);

  /// Secondary Background — app bars, bottom sheets, nav bar chrome.
  /// One step of "elevation" above [background], same direction light
  /// Material surfaces normally move (whiter, not darker).
  static const Color backgroundDark = Color(0xFFFFFFFF);

  /// Surface/Card — cards, dialogs, elevated content. The spec gives
  /// one hex for both roles, so [surface] and [card] share a value.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  /// The app's single accent color. Reserved for: active bottom nav,
  /// active tab, active radius/switch, online status, map marker,
  /// primary CTA buttons, loading/progress indicators, links, focus
  /// state, selected elements. Never used as a decorative/default
  /// icon or border tint — see [textSecondary]/[divider] for those.
  static const Color primary = Color(0xFF2DD4BF);

  /// Primary text/icon color — dark ink, not literal white (see the
  /// class doc comment for why the name stayed).
  static const Color white = Color(0xFF1B2528);

  static const Color textSecondary = Color(0xFF5B6B70);

  /// Disabled elements / the dimmest text tier (below [textSecondary]).
  static const Color textMuted = Color(0xFF93A2A6);

  /// The dark ink color for text/icons drawn ON TOP of an
  /// [primary]-filled surface (filled button labels, spinners inside a
  /// filled button, an icon inside an accent-colored badge/circle) —
  /// deliberately its OWN token rather than reusing [background],
  /// since [background] flipped polarity in the light rebrand and a
  /// dark accent-fill still needs dark-on-light... no, needs a fixed
  /// dark ink regardless of what the page background happens to be.
  static const Color onAccent = Color(0xFF1B2528);

  /// Caption text drawn directly over a photo (swipe cards, profile
  /// hero) rather than a flat surface — kept as translucent white
  /// since it's a photo-contrast concern, independent of the app's
  /// own light/dark surface palette above.
  static const Color captionText = Colors.white70;

  static const Color error = Color(0xFFFF6B6B);

  /// Border & Divider — one value shared by both roles per spec.
  static const Color divider = Color(0xFFDDE2E6);

  /// Small gold accent reserved for Premium/VIP-tier badges (crown,
  /// "VIP" pill) — deliberately NOT the app's interactive accent, so a
  /// VIP badge reads as its own distinct tier rather than looking like
  /// an active/selected state.
  static const Color gold = Color(0xFFFFC94D);

  /// Neutral scrim behind text overlaid on a photo (swipe card bottom
  /// gradient, photo placeholder) — kept dark/near-black regardless of
  /// the app's own light theme, since it sits on top of a PHOTO, not
  /// app chrome, and photo captions still need dark-scrim-behind-white-
  /// text contrast either way.
  static const Color cardOverlay = Color(0xE6121212);
}
