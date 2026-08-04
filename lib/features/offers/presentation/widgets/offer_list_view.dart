import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/distance_formatter.dart';
import '../../../../core/utils/distance_unit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../settings/map_location/presentation/providers/map_location_providers.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;
import '../../domain/entities/offer.dart';
import '../providers/offer_providers.dart';
import '../screens/offer_details_screen.dart';
import 'offer_filter_sheet.dart';

/// Collapses the Azerbaijani/Turkish İ/I/ı family down to plain ASCII
/// 'i' — same fix, same reasoning as `chats_tab.dart`'s private
/// `_azSearchKey` (duplicated rather than shared: one small function,
/// no other coupling between the two screens).
String _azSearchKey(String value) {
  return value.replaceAll('İ', 'i').replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase();
}

/// The full localized type label ("Endirim", "Hədiyyə", ...) — lets the
/// search field match a type by name (typing "endirim" surfaces every
/// discount offer) even when that word never appears in any offer's own
/// title/description text.
String offerTypeSearchLabel(AppLocalizations loc, OfferType type) {
  return switch (type) {
    OfferType.discount => loc.offerTypeDiscountOption,
    OfferType.gift => loc.offerTypeGiftOption,
    OfferType.buyOneGetOne => loc.offerTypeBuyOneGetOneOption,
    OfferType.fixedPrice => loc.offerTypeFixedPriceOption,
  };
}

/// Kəşf et → Təkliflər. Same light-theme-exception scope boundary as
/// `_VenueListView` — only this content area goes light, the shared
/// Discover header/switcher stays dark.
class OfferListView extends ConsumerStatefulWidget {
  const OfferListView({super.key});

  @override
  ConsumerState<OfferListView> createState() => _OfferListViewState();
}

class _OfferListViewState extends ConsumerState<OfferListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final selected = ref.read(selectedOfferCategoryFilterProvider);
    final result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: ChatLightColors.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => OfferFilterSheet(selected: selected),
    );
    if (!mounted) return;

    // null here is genuinely "dismissed without choosing" (scrim tap /
    // back button) — leave the filter untouched. An explicit "Hamısı"
    // tap pops ClearOfferCategoryFilter instead, which is what actually
    // clears it; see that class's doc comment for why they can't share
    // the same null result.
    if (result == null) return;
    if (result is ClearOfferCategoryFilter) {
      ref.read(selectedOfferCategoryFilterProvider.notifier).state = null;
    } else if (result is VenueCategory) {
      ref.read(selectedOfferCategoryFilterProvider.notifier).state = result;
    }
  }

  List<OfferWithDistance> _visible(List<OfferWithDistance> all) {
    if (_query.isEmpty) return all;
    final loc = AppLocalizations.of(context);
    final q = _azSearchKey(_query);
    return all.where((item) {
      final offer = item.offer;
      return _azSearchKey(offer.title).contains(q) ||
          _azSearchKey(offer.venueName).contains(q) ||
          _azSearchKey(offer.description).contains(q) ||
          _azSearchKey(offerTypeSearchLabel(loc, offer.offerType)).contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final offersAsync = ref.watch(nearbyOffersProvider);
    final distanceUnit = ref.watch(mapLocationSettingsProvider).valueOrNull?.distanceUnit ?? DistanceUnit.km;
    final selectedCategory = ref.watch(selectedOfferCategoryFilterProvider);

    return Stack(
      children: [
        const ChatLightBackground(),
        Positioned.fill(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: _OfferSearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  onFilterTap: _openFilterSheet,
                  filterActive: selectedCategory != null,
                ),
              ),
              Expanded(
                child: offersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
                  error: (error, _) => _OfferStatusMessage(
                    icon: Icons.error_outline,
                    title: loc.errorTitle,
                    subtitle: '$error',
                    actionLabel: loc.actionRetry,
                    onAction: () => ref.invalidate(nearbyOffersProvider),
                  ),
                  data: (offers) {
                    final visible = _visible(offers);
                    if (visible.isEmpty) {
                      return _OfferStatusMessage(
                        icon: Icons.local_offer_outlined,
                        title: loc.offersEmptyTitle,
                        subtitle: loc.offersEmptySubtitle,
                      );
                    }
                    return ListView.separated(
                      // Extra bottom padding so the last card doesn't sit
                      // under the persistent radius selector now pinned
                      // below this list (see discover_tab.dart).
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _OfferCard(item: visible[index], loc: loc, distanceUnit: distanceUnit),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool filterActive;

  const _OfferSearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    required this.filterActive,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: loc.offersSearchHint,
                hintStyle: const TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
                prefixIcon: const Icon(Icons.search, color: ChatLightColors.inkFaint, size: 21),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: ChatLightColors.inkFaint, size: 18),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onFilterTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: filterActive ? AppColors.primary : ChatLightColors.inkSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final OfferWithDistance item;
  final AppLocalizations loc;
  final DistanceUnit distanceUnit;

  const _OfferCard({required this.item, required this.loc, required this.distanceUnit});

  @override
  Widget build(BuildContext context) {
    final offer = item.offer;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OfferDetailsScreen(offerId: offer.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OfferVenueLogo(offer: offer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.venueName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (offer.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        offer.description,
                        style: TextStyle(fontSize: 12.5, color: ChatLightColors.inkSoft, height: 1.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12.5, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            formatDistance(loc, item.distanceMeters, distanceUnit),
                            style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.schedule_outlined, size: 12.5, color: ChatLightColors.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          loc.offerEndsOnLabel(DateFormat('d MMM').format(offer.endDate)),
                          style: TextStyle(fontSize: 11.5, color: ChatLightColors.inkFaint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CategoryPill(category: offer.category),
                  const SizedBox(height: 6),
                  _OfferTypeBadge(offer: offer),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferVenueLogo extends StatelessWidget {
  final Offer offer;

  const _OfferVenueLogo({required this.offer});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 52,
        height: 52,
        child: offer.venuePhotoUrl != null
            ? Image.network(offer.venuePhotoUrl!, fit: BoxFit.cover)
            : Container(
                color: ChatLightColors.cardSurface,
                alignment: Alignment.center,
                child: Icon(venueCategoryIcon(offer.category), color: ChatLightColors.inkSoft, size: 24),
              ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final VenueCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ChatLightColors.cardSurface, borderRadius: BorderRadius.circular(8)),
      child: Text(
        venueCategoryLabel(loc, category),
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ChatLightColors.inkSoft),
      ),
    );
  }
}

/// Colored per offer type, matching the approved reference mockup —
/// [OfferType.fixedPrice] shows only the real stored price, never a
/// fabricated "original price" strikethrough (this app has no such
/// field, and never shows a number it didn't actually store).
class _OfferTypeBadge extends StatelessWidget {
  final Offer offer;

  const _OfferTypeBadge({required this.offer});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final (color, lines) = switch (offer.offerType) {
      OfferType.discount => (AppColors.primary, ['${offer.discountValue?.round() ?? 0}%', loc.offerBadgeDiscountSuffix]),
      OfferType.fixedPrice => (const Color(0xFF18C964), ['${offer.discountValue?.round() ?? 0}', loc.offerBadgeFixedPriceSuffix]),
      OfferType.gift => (const Color(0xFFF5A524), [loc.offerBadgeGiftLabel]),
      OfferType.buyOneGetOne => (const Color(0xFF7C6CF2), [loc.offerBadgeBuyOneGetOneLabel, loc.offerBadgeGiftLabel]),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(minWidth: 64),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color, height: 1.15),
            ),
        ],
      ),
    );
  }
}

class _OfferStatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _OfferStatusMessage({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.1)),
              child: Icon(icon, color: AppColors.primary, size: 38),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ChatLightColors.inkSoft, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
