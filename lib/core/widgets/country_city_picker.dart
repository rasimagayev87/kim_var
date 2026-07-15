import 'package:flutter/material.dart';

import '../data/countries_cities.dart';
import '../theme/app_colors.dart';

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
    final selected = await _showSearchSheet(
      context,
      title: 'Ölkə seç',
      hint: 'Ölkə axtar',
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
    final cities = kCitiesByCountry[_country] ?? const [];
    final selected = await _showSearchSheet(
      context,
      title: 'Şəhər seç',
      hint: 'Şəhər axtar',
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
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        autofocus: false,
                        style: const TextStyle(color: AppColors.white, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('Tapılmadı', style: TextStyle(color: AppColors.textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(item, style: const TextStyle(color: AppColors.white, fontSize: 14.5)),
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
    return Column(
      children: [
        _SelectorField(
          label: 'Ölkə',
          value: _country,
          hint: 'Ölkə seç',
          icon: Icons.public,
          onTap: _pickCountry,
        ),
        const SizedBox(height: 16),
        _SelectorField(
          label: 'Şəhər',
          value: _city,
          hint: _country == null ? 'Əvvəlcə ölkə seç' : 'Şəhər seç',
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
                    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      value ?? hint,
                      style: TextStyle(
                        color: value == null ? AppColors.textMuted : AppColors.white,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
