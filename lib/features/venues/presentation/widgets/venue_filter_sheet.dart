import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/venue.dart';
import '../screens/create_venue_screen.dart' show venueCategoryLabel;

/// Distinguishes "the user tapped Hamısı" (pop this, meaning "clear
/// the filter") from "the sheet was dismissed without a choice" — see
/// `ClearOfferCategoryFilter` in the offers feature for the identical
/// reasoning (not shared between the two features on purpose, same as
/// every other small widget duplicated across Venues/Offers).
class ClearVenueCategoryFilter {
  const ClearVenueCategoryFilter();
}

/// The Məkanlar search bar's filter icon opens this — search + flat
/// filterable category list, plus a leading "Hamısı" row. Pops a
/// [VenueCategory], a [ClearVenueCategoryFilter], or nothing at all
/// (dismissed).
class VenueFilterSheet extends StatefulWidget {
  final VenueCategory? selected;

  const VenueFilterSheet({super.key, required this.selected});

  @override
  State<VenueFilterSheet> createState() => _VenueFilterSheetState();
}

class _VenueFilterSheetState extends State<VenueFilterSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final categories = VenueCategory.values
        .where((c) => query.isEmpty || venueCategoryLabel(loc, c).toLowerCase().contains(query))
        .toList();

    return SafeArea(
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
              loc.venueCategoryFilterTitle,
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
                    _VenueCategoryRow(
                      label: loc.venueCategoryAllOption,
                      isSelected: widget.selected == null,
                      onTap: () => Navigator.pop(context, const ClearVenueCategoryFilter()),
                    ),
                  for (final category in categories)
                    _VenueCategoryRow(
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
    );
  }
}

class _VenueCategoryRow extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VenueCategoryRow({required this.label, this.icon, required this.isSelected, required this.onTap});

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
