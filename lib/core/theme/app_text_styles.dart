import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared text style tokens for screens that build their own typography
/// ad hoc (feed, about, contact) instead of pulling from [ThemeData]'s
/// `textTheme` — same Poppins family [AppTheme.darkTheme] uses, so text
/// outside a `Text.rich`/default style still matches.
class AppTextStyles {
  static TextStyle get h1 => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      );

  static TextStyle get cardTitle => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.white,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
}
