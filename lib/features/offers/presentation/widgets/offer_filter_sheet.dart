import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/presentation/screens/create_venue_screen.dart' show venueCategoryLabel;

/// Distinguishes "the user tapped Hamısı" (pop this, meaning "clear
/// the filter") from "the sheet was dismissed without a choice" (pop
/// nothing, `Navigator.pop`'s ordinary `null`) — both would otherwise
/// be indistinguishable `null` results, silently turning a deliberate
/// "show everything" tap into a no-op.
class ClearOfferCategoryFilter {
  const ClearOfferCategoryFilter();
}

/// The Təkliflər search bar's filter icon opens this — search +
/// flat filterable category list, same shape as Venues' own
/// `_CategoryPickerSheet`, plus a leading "Hamısı" row (absent from
/// the venues picker, which always requires exactly one category —
/// here "no filter" is itself a valid, common choice). Pops a
/// [VenueCategory], a [ClearOfferCategoryFilter], or nothing at all
/// (dismissed) — see [ClearOfferCategoryFilter] for why those last two
/// are kept distinct.
class OfferFilterSheet extends StatefulWidget {
  final VenueCategory? selected;

  const OfferFilterSheet({super.key, required this.selected});

  @override
  State<OfferFilterSheet> createState() => _OfferFilterSheetState();
}

class _OfferFilterSheetState extends State<OfferFilterSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final categories = VenueCategory.values
        .where((c) => query.isEmpty || venueCategoryLabel(loc, c).toLowerCase().contains(query))
        .toList();

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ChatLightColors.inkFaint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              loc.offerCategoryFilterTitle,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ChatLightColors.ink),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: ChatLightColors.inkFaint.withValues(alpha: 0.18)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: ChatLightColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 14.5, color: ChatLightColors.ink),
                      decoration: InputDecoration(
                        hintText: loc.venueCategorySearchHint,
                        hintStyle: TextStyle(color: ChatLightColors.inkFaint, fontSize: 14.5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                children: [
                  if (query.isEmpty)
                    _OfferCategoryRow(
                      label: loc.offerCategoryAllOption,
                      isSelected: widget.selected == null,
                      onTap: () => Navigator.pop(context, const ClearOfferCategoryFilter()),
                    ),
                  for (final category in categories)
                    _OfferCategoryRow(
                      label: venueCategoryLabel(loc, category),
                      icon: venueCategoryIcon(category),
                      isSelected: category == widget.selected,
                      onTap: () => Navigator.pop(context, category),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _OfferCategoryRow extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OfferCategoryRow({required this.label, this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.14) : ChatLightColors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon ?? Icons.apps_rounded,
                  size: 18,
                  color: isSelected ? AppColors.primary : ChatLightColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                ),
              ),
              if (isSelected) const Icon(Icons.check, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
