import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Renders a static legal document (Terms of Service, Privacy
/// Policy) with a simple markdown-like structure: lines starting
/// with "# " become section headings, everything else is body text.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = content.trim().split('\n\n');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            final block = blocks[index].trim();
            final isHeading = block.startsWith('# ');
            final text = isHeading ? block.substring(2) : block;

            return Padding(
              padding: EdgeInsets.only(
                top: isHeading && index != 0 ? 22 : 0,
                bottom: isHeading ? 10 : 14,
              ),
              child: Text(
                text,
                style: isHeading
                    ? const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      )
                    : const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
