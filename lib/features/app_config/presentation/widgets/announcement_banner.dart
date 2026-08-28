import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/app_config_providers.dart';

const _kDismissedIdKey = 'announcement_dismissed_id';

/// A dismissible banner sourced entirely from Remote Config — the only
/// way to reach users without shipping a new build. Dismissal is keyed
/// by `announcement_id`, so a *new* announcement (new id) reappears
/// even if the previous one was dismissed; the same id never shows again
/// once dismissed.
class AnnouncementBanner extends ConsumerStatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  ConsumerState<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends ConsumerState<AnnouncementBanner> {
  String? _dismissedId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _dismissedId = prefs.getString(_kDismissedIdKey);
        _loaded = true;
      });
    });
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissedId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedIdKey, id);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);

    final shouldShow = _loaded &&
        config.announcementEnabled &&
        config.announcementId.isNotEmpty &&
        config.announcementMessage.isNotEmpty &&
        config.announcementId != _dismissedId;

    if (!shouldShow) return const SizedBox.shrink();

    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: config.announcementActionUrl.isEmpty
            ? null
            : () => launchUrl(Uri.parse(config.announcementActionUrl), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.announcementMessage,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                tooltip: loc.announcementDismissLabel,
                onPressed: () => _dismiss(config.announcementId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
