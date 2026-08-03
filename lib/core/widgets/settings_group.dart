import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Rounded card wrapping a set of [SettingsMenuRow]s — the shared
/// "settings section" chrome used across Legal/About/etc.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 54),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One tappable row inside a [SettingsGroup] — icon, title, and either
/// a caller-supplied [trailing] widget or (when [onTap] is set and no
/// [trailing] is given) a default chevron.
class SettingsMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: AppTextStyles.body.copyWith(fontSize: 15)),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textMuted) : null),
      onTap: onTap,
    );
  }
}

/// Small rounded label badge — version numbers, "Tezliklə", etc.
class SettingsPill extends StatelessWidget {
  final String label;
  final Color color;

  const SettingsPill({super.key, required this.label, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11.5),
      ),
    );
  }
}
