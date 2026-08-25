import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/settings_group.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/support_message.dart';
import '../widgets/contact_us_sheet.dart';
import '../widgets/support_message_sheet.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final faqs = [
      (loc.helpFaq1Question, loc.helpFaq1Answer),
      (loc.helpFaq2Question, loc.helpFaq2Answer),
      (loc.helpFaq3Question, loc.helpFaq3Answer),
      (loc.helpFaq4Question, loc.helpFaq4Answer),
      (loc.helpFaq5Question, loc.helpFaq5Answer),
      (loc.helpFaq6Question, loc.helpFaq6Answer),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.helpScreenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(loc.helpFaqSectionTitle, style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SettingsGroup(
              children: [for (final (question, answer) in faqs) _FaqTile(question: question, answer: answer)],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              children: [
                SettingsMenuRow(
                  icon: Icons.mail_outline,
                  title: loc.helpContactRowTitle,
                  subtitle: loc.helpContactRowSubtitle,
                  onTap: () => showContactUsSheet(context),
                ),
                SettingsMenuRow(
                  icon: Icons.report_problem_outlined,
                  iconColor: AppColors.error,
                  title: loc.helpReportProblemRowTitle,
                  subtitle: loc.helpReportProblemRowSubtitle,
                  onTap: () => showSupportMessageSheet(context, SupportMessageType.problem),
                ),
                SettingsMenuRow(
                  icon: Icons.lightbulb_outline,
                  title: loc.helpSendSuggestionRowTitle,
                  subtitle: loc.helpSendSuggestionRowSubtitle,
                  onTap: () => showSupportMessageSheet(context, SupportMessageType.suggestion),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 20),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.answer,
                        style: AppTextStyles.caption.copyWith(fontSize: 13.5, height: 1.5),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
