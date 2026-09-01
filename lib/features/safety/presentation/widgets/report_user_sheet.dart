import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/safety_providers.dart';

Future<void> showReportUserSheet(
  BuildContext context,
  WidgetRef ref, {
  required String reportedId,
  String? chatId,
}) {
  final loc = AppLocalizations.of(context);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) =>
        _ReportUserSheet(reportedId: reportedId, chatId: chatId, loc: loc),
  );
}

class _ReportUserSheet extends ConsumerStatefulWidget {
  final String reportedId;
  final String? chatId;
  final AppLocalizations loc;

  const _ReportUserSheet({
    required this.reportedId,
    required this.chatId,
    required this.loc,
  });

  @override
  ConsumerState<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<_ReportUserSheet> {
  final _otherReasonController = TextEditingController();
  late final List<String> _reasons;
  String? _selectedReason;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final loc = widget.loc;
    _reasons = [
      loc.chatReportReasonInappropriate,
      loc.chatReportReasonFakeProfile,
      loc.chatReportReasonDangerous,
      loc.chatReportReasonOther,
    ];
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  bool get _isOtherSelected =>
      _selectedReason == widget.loc.chatReportReasonOther;

  bool get _canSubmit {
    if (_selectedReason == null) return false;
    if (_isOtherSelected) return _otherReasonController.text.trim().isNotEmpty;
    return true;
  }

  Future<void> _submit() async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || !_canSubmit) return;

    final reason = _isOtherSelected
        ? _otherReasonController.text.trim()
        : _selectedReason!;

    setState(() => _sending = true);
    try {
      await ref
          .read(reportUserUseCaseProvider)
          .call(
            reporterId: myUid,
            reportedId: widget.reportedId,
            reason: reason,
            chatId: widget.chatId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.loc.chatReportSentNotice)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.errorWithDetails(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.chatReportTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map(
              (reason) => _ReasonTile(
                label: reason,
                selected: _selectedReason == reason,
                onTap: () => setState(() => _selectedReason = reason),
              ),
            ),
            if (_isOtherSelected) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _otherReasonController,
                maxLines: 3,
                autofocus: true,
                // Matches firestore.rules' new `reason.size() <= 1000`
                // (Düzəliş Prompt 8 / RT-2, shared by reports/eventReports/reviewReports).
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.body.copyWith(fontSize: 15),
                decoration: InputDecoration(hintText: loc.chatReportReasonHint),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_sending || !_canSubmit) ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Text(loc.chatReportSubmitButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.primary.withOpacity(0.12) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      color: selected
                          ? AppColors.white
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
