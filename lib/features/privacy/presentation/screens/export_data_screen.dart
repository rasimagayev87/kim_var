import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/privacy_providers.dart';

/// "Məlumatlarımı yüklə" — fetches everything `AccountRepository
/// .exportUserData` gathers (profile, posts, reviews, payment
/// history, saved cards, follows, notifications) as readable JSON and
/// lets the user copy it. Deliberately still copy-to-clipboard, not a
/// downloadable file — that would need either a new package (to
/// write+share a file) or a server-side export job, worth revisiting
/// separately; message threads and other cross-user data stay out of
/// scope entirely, see the repository method's own doc comment.
class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  String? _json;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ref.read(accountControllerProvider).exportUserData();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _json = result;
    });
  }

  Future<void> _copy() async {
    final json = _json;
    if (json == null) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.exportDataCopiedNotice)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.white),
        ),
        title: Text(loc.exportDataScreenTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _json == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, color: AppColors.textMuted, size: 36),
                          const SizedBox(height: 14),
                          Text(loc.exportDataLoadErrorMessage, textAlign: TextAlign.center, style: AppTextStyles.caption),
                          const SizedBox(height: 16),
                          TextButton(onPressed: _load, child: Text(loc.actionRetry)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
                            child: SelectableText(
                              _json!,
                              style: AppTextStyles.body.copyWith(fontSize: 12.5, fontFamily: 'monospace', height: 1.5),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: ElevatedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.onAccent),
                          label: Text(loc.exportDataCopyButton),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
