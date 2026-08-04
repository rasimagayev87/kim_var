import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography scale for the whole app. Every screen should pull
/// its text styles from here (or from `Theme.of(context).textTheme`, which
/// is built from these same values in `AppTheme`) instead of hand-rolling
/// `TextStyle(fontSize: ..., fontWeight: ...)` per widget — that's what
/// kept the app feeling inconsistent/"stock Material" before.
class AppTextStyles {
  AppTextStyles._();

  /// Page headlines ("Profili tamamla"...). 700, 30-32.
  static TextStyle h1 = GoogleFonts.manrope(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: AppColors.white,
    height: 1.2,
  );

  /// Top-of-tab titles ("Kəşf et", "Söhbətlər", "Tədbirlər", "Profil").
  /// Deliberately lighter and tighter than [h1] — 600 weight, negative
  /// tracking, Plus Jakarta Sans — for an iOS-native "premium" feel
  /// rather than a heavy display headline. Sized down from the original
  /// 30 to read as a compact tab header instead of a hero headline.
  static TextStyle pageTitle = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.white,
    height: 1.2,
  );

  /// Section headings ("Ölkə və şəhər", "Maraq sahələri"...). 600, 20-22.
  static TextStyle sectionTitle = GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.white,
    height: 1.25,
  );

  /// Card / list-item titles (user names on cards, row titles...). 500-600, 17-18.
  static TextStyle cardTitle = GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AppColors.white,
    height: 1.3,
  );

  /// Regular body copy. 400, 15-16.
  static TextStyle body = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.white,
    height: 1.45,
  );

  /// Slightly smaller body copy (secondary paragraphs, list rows). 400, 15.
  static TextStyle bodySmall = GoogleFonts.manrope(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Small explanatory / helper text (row subtitles, hints, empty
  /// states...) — used all over the app, on the app's own light
  /// surfaces, so it defaults to the dimmest ink tier. This is
  /// deliberately NOT [AppColors.captionText] (translucent white) —
  /// that token is reserved for text drawn directly over a photo/video,
  /// where callers pass it (or plain `Colors.white`) explicitly via
  /// `.copyWith`. Using it as this style's default was the exact bug
  /// that made every settings-row subtitle (and most helper text
  /// app-wide) unreadable after the light-theme rebrand: white-ish text
  /// on a now-white surface.
  static TextStyle caption = GoogleFonts.manrope(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// Button labels — always SemiBold per the design spec.
  static TextStyle button = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// The current user's own display name — meant to stand out more than
  /// any other text on the profile screen.
  static TextStyle profileName = GoogleFonts.manrope(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.white,
    height: 1.2,
  );
}
