import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme.light(
      surface: AppColors.surface,
      primary: AppColors.primary,
      // Dark ink on the cyan accent — see AppColors.onAccent's doc
      // comment for why this is its own token, not AppColors.background.
      onPrimary: AppColors.onAccent,
      secondary: AppColors.primary,
      error: AppColors.error,
    ),

    fontFamily: GoogleFonts.manrope().fontFamily,

    textTheme: TextTheme(
      displayLarge: AppTextStyles.h1,
      headlineLarge: AppTextStyles.h1,
      headlineMedium: AppTextStyles.sectionTitle,
      titleLarge: AppTextStyles.sectionTitle,
      titleMedium: AppTextStyles.cardTitle,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.bodySmall,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.button,
      labelSmall: AppTextStyles.caption,
    ).apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    ),

    // Kills the stock Material ripple/highlight so buttons, list rows and
    // nav items rely on our own state styling instead of the default
    // Android "Material feel".
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    // iOS-style slide transition on both platforms — replaces the default
    // Android zoom/fade route animation, which is one of the biggest
    // "stock Material" tells. ~300ms, matching the 250-300ms brief.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      titleTextStyle: AppTextStyles.sectionTitle,
      iconTheme: const IconThemeData(color: AppColors.white),
    ),

    // Default color/size for any Icon() that doesn't specify its own —
    // "normal state" per the design spec. Active/selected icons should
    // still explicitly pass AppColors.primary; this only sets the
    // baseline so nothing accidentally falls back to a stock Material
    // default color.
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.divider,
        disabledForegroundColor: AppColors.textMuted,
        // A soft, low elevation instead of a hard drop shadow or glow —
        // "yumşaq kölgə", not neon.
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        minimumSize: const Size(double.infinity, 56),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),

    // Secondary action button — deliberately neutral (divider border,
    // primary text) rather than accent-colored, since the design spec
    // reserves the accent for primary CTAs only.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(
          color: AppColors.divider,
          width: 1.2,
        ),
        minimumSize: const Size(double.infinity, 56),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),

    // Links — one of the whitelisted accent contexts.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.button.copyWith(fontSize: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,

      hintStyle: AppTextStyles.body.copyWith(
        color: AppColors.textMuted,
        fontSize: 15,
      ),

      labelStyle: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
        fontSize: 15,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),

      // Focus state — one of the whitelisted accent contexts.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.2,
        ),
      ),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),

    // Active switch — one of the whitelisted accent contexts.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.divider,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    // Loading/progress indicator — one of the whitelisted accent contexts.
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.divider,
      circularTrackColor: AppColors.divider,
    ),
  );
}
