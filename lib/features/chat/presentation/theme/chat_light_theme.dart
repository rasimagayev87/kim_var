import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The chat feature (conversation screen + Söhbətlər list) is a
/// deliberate exception to the app's dark theme — a calm, light
/// "messaging" surface, closer to WhatsApp/Telegram than the rest of
/// PeakPin. These tokens are shared between both chat screens so they
/// stay pixel-identical; reusing [AppColors] instead would mean
/// fighting a dark-mode palette (white text, dark cards) on what's now
/// a light background.
class ChatLightColors {
  static const ink = Color(0xFF1B2528);
  static const inkSoft = Color(0xFF5B6B70);
  static const inkFaint = Color(0xFF93A2A6);
  static const bg1 = Color(0xFFEEF1F4);
  static const bg2 = Color(0xFFE7ECF1);
  static const bg3 = Color(0xFFEAF3F2);

  /// A step darker/greyer than [bg1]/[bg2] — used where a surface
  /// needs to read as "raised" against the page background (Söhbətlər
  /// search bar, filter chips, chat cards) without an actual shadow.
  static const cardSurface = Color(0xFFDEE3E8);

  static const bubbleTheirs = Colors.white;
  static const bubbleMineStart = Color(0xFFE4FBF7);
  static const composerFill = Color(0xFFE4E8EC);
  static const barTint = Color(0xFFEEF1F4);
  static const onlineGreen = AppColors.cyanDark;
  static const onlineDot = AppColors.cyanLight;
  static const contourLine = Color(0xFF0E3B36);
}
