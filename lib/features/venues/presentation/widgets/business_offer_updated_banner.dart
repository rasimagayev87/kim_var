import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/venue.dart';

import '../../../../core/widgets/pressable.dart';

const _kDismissedVersionPrefix = 'business_offer_banner_dismissed_';

/// Non-blocking "oferta yeniləndi" notice on `MyVenuesScreen` — shown
/// when at least one of the owner's venues has an [Venue.offerAcceptedVersion]
/// that no longer matches `AppConfig.businessOfferVersion`. Never
/// blocks the screen (unlike `showBusinessOfferReacceptSheet`, which
/// blocks payment) — actual re-acceptance still only happens at the
/// next subscription payment.
///
/// Dismissal is keyed by version (same pattern as `AnnouncementBanner`'s
/// `announcement_id`-keyed dismissal) so a *further* version bump shows
/// again even if this one was dismissed.
class BusinessOfferUpdatedBanner extends ConsumerStatefulWidget {
  final List<Venue> venues;

  const BusinessOfferUpdatedBanner({super.key, required this.venues});

  @override
  ConsumerState<BusinessOfferUpdatedBanner> createState() =>
      _BusinessOfferUpdatedBannerState();
}

class _BusinessOfferUpdatedBannerState
    extends ConsumerState<BusinessOfferUpdatedBanner> {
  String? _dismissedVersion;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final currentVersion = ref.read(appConfigProvider).businessOfferVersion;
      setState(() {
        _dismissedVersion = prefs.getString(
          '$_kDismissedVersionPrefix$currentVersion',
        );
        _loaded = true;
      });
    });
  }

  Future<void> _dismiss(String version) async {
    setState(() => _dismissedVersion = version);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kDismissedVersionPrefix$version', version);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);

    final anyVenueOutOfDate = widget.venues.any(
      (v) =>
          v.offerAcceptedVersion != null &&
          v.offerAcceptedVersion != config.businessOfferVersion,
    );
    final shouldShow =
        _loaded &&
        anyVenueOutOfDate &&
        config.businessOfferVersion != _dismissedVersion;
    if (!shouldShow) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => launchUrl(
                Uri.parse(config.urlBusinessOffer),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                loc.businessOfferUpdatedBannerMessage(
                  config.businessOfferEffectiveDate,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ChatLightColors.ink,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: ChatLightColors.inkSoft,
            ),
            tooltip: loc.businessOfferUpdatedBannerDismiss,
            onPressed: () => _dismiss(config.businessOfferVersion),
          ),
        ],
      ),
    );
  }
}
