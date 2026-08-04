/// Unified spacing scale — every padding/margin/gap in the app should
/// come from here rather than a one-off magic number, so density
/// reads consistently across screens.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Unified corner-radius scale.
class AppRadii {
  AppRadii._();

  /// Buttons — 16-18px per the design spec.
  static const double button = 16;

  /// Cards / elevated surfaces — 18-22px per the design spec.
  static const double card = 20;

  /// Bottom sheets.
  static const double sheet = 24;

  /// Text fields / input decoration.
  static const double input = 16;

  /// Fully-rounded pills/badges.
  static const double pill = 100;
}
