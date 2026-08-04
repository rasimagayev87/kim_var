import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Generic placeholder screen for features that are announced in the
/// UI (nav entries, menu rows) before their real implementation lands.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? message;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.icon = Icons.hourglass_top_outlined,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message ?? AppLocalizations.of(context).comingSoonDefaultMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 0),
                  ],
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 42),
              ),
              const SizedBox(height: 24),
              Text(
                resolvedMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(height: 1.5, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
