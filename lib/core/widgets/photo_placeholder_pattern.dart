import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Decorative fallback painted wherever a photo/video `Image.network`
/// fails to load (missing file, dead URL, offline) — a plain broken-
/// image icon reads as "app is broken"; this reads as "no photo yet".
class PhotoPlaceholderPattern extends StatelessWidget {
  const PhotoPlaceholderPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 40),
    );
  }
}
