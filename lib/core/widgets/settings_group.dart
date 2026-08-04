import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One rounded container per group, thin dividers BETWEEN rows (not
/// around each row individually) — the grouped-list look used across
/// every "Ayarlar" sub-screen (Hesab, Məxfilik, Bildirişlər, ...),
/// extracted here so each screen doesn't reimplement it.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: AppColors.card,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 66),
                  child: Divider(height: 1, thickness: 1, color: AppColors.divider),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsMenuRow extends StatelessWidget {
  final IconData icon;

  /// Optional override — leave unset for the standard neutral badge.
  /// Only pass a color for genuinely semantic rows (destructive actions
  /// use [AppColors.error]); decorative per-row "brand" colors are
  /// deliberately not a thing anymore, so every row reads as one
  /// consistent monochrome icon system.
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const SettingsMenuRow({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = iconColor ?? AppColors.textSecondary;
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: resolvedColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.white),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            // No chevron on a row with no tap action — showing one
            // would imply navigation that doesn't actually happen.
            if (onTap != null) const Icon(Icons.chevron_right_outlined, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A [SettingsMenuRow] with a [Switch] instead of a chevron — for
/// toggle-only rows (notifications, online status, ...). Tapping
/// anywhere on the row toggles it, matching standard settings-screen
/// behavior, not just tapping the switch itself.
class SettingsToggleRow extends StatelessWidget {
  final IconData icon;

  /// Optional override — leave unset for the standard neutral badge
  /// (see [SettingsMenuRow.iconColor] for why per-row brand colors
  /// were removed).
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Optional small pill rendered between the title/subtitle column and
  /// the switch — e.g. a "VIP" badge on a premium-gated toggle.
  final Widget? badge;

  const SettingsToggleRow({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = iconColor ?? AppColors.textSecondary;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.backgroundDark, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: resolvedColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[badge!, const SizedBox(width: 6)],
            Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class SettingsPill extends StatelessWidget {
  final String label;
  final Color color;

  const SettingsPill({super.key, required this.label, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
