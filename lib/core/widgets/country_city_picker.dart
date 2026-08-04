import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/countries_cities.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A self-contained Country → City picker built entirely with our
/// own widgets (no third-party picker package) — searchable bottom
/// sheets backed by [kCountryNames] / [kCitiesByCountry]. City
/// resets whenever the country changes.
class CountryCityPicker extends StatefulWidget {
  final String? initialCountry;
  final String? initialCity;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onCityChanged;

  const CountryCityPicker({
    super.key,
    this.initialCountry,
    this.initialCity,
    required this.onCountryChanged,
    required this.onCityChanged,
  });

  @override
  State<CountryCityPicker> createState() => _CountryCityPickerState();
}

class _CountryCityPickerState extends State<CountryCityPicker> {
  String? _country;
  String? _city;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
    _city = widget.initialCity;
  }

  Future<void> _pickCountry() async {
    final loc = AppLocalizations.of(context);
    final selected = await _showSearchSheet(
      context,
      title: loc.pickCountryTitle,
      hint: loc.pickCountryHint,
      items: kCountryNames,
    );
    if (selected == null) return;
    setState(() {
      _country = selected;
      _city = null;
    });
    widget.onCountryChanged(selected);
    widget.onCityChanged(null);
  }

  Future<void> _pickCity() async {
    if (_country == null) return;
    final loc = AppLocalizations.of(context);
    final cities = kCitiesByCountry[_country] ?? const [];
    final selected = await _showSearchSheet(
      context,
      title: loc.pickCityTitle,
      hint: loc.pickCityHint,
      items: cities,
    );
    if (selected == null) return;
    setState(() => _city = selected);
    widget.onCityChanged(selected);
  }

  Future<String?> _showSearchSheet(
    BuildContext context, {
    required String title,
    required String hint,
    required List<String> items,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = query.isEmpty
                ? items
                : items.where((i) => i.toLowerCase().contains(query.toLowerCase())).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Text(
                        title,
                        textAlign: TextAlign.left,
                        style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        autofocus: false,
                        style: AppTextStyles.body.copyWith(fontSize: 15.5),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: const Icon(Icons.search_outlined, color: AppColors.textSecondary, size: 20),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(AppLocalizations.of(context).searchNotFound, style: AppTextStyles.bodySmall),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(item, style: AppTextStyles.body.copyWith(fontSize: 15.5)),
                                  onTap: () => Navigator.pop(sheetContext, item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        _SelectorField(
          label: loc.fieldCountryLabel,
          value: _country,
          hint: loc.pickCountryTitle,
          icon: Icons.public_outlined,
          onTap: _pickCountry,
        ),
        const SizedBox(height: 16),
        _SelectorField(
          label: loc.fieldCityLabel,
          value: _city,
          hint: _country == null ? loc.fieldCitySelectFirstHint : loc.pickCityTitle,
          icon: Icons.location_city_outlined,
          enabled: _country != null,
          onTap: _pickCity,
        ),
      ],
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _SelectorField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.caption),
                    const SizedBox(height: 3),
                    Text(
                      value ?? hint,
                      style: AppTextStyles.body.copyWith(
                        color: value == null ? AppColors.textMuted : AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_outlined, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
