import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/theme/chat_light_theme.dart';
import '../../domain/entities/venue.dart';

const _kDefaultOpen = '09:00';
const _kDefaultClose = '18:00';

/// Opening-hours form section: a "24 saat açıqdır" toggle that hides
/// everything else when on, and — when off — either one shared
/// open/close pair applied to all 7 days ("Hər gün eyni saat") or a
/// fully independent per-day editor. The "same every day" split is
/// purely a data-entry convenience: [OpeningHours.schedule] itself is
/// always stored per-day either way, so there's exactly one shape for
/// `create_venue_screen.dart`/the repository to reason about.
///
/// Styled for the light Venues form (same [ChatLightColors] tokens as
/// the chat screens) — every color here is explicit rather than
/// pulled from the app's global (dark) theme, since Switch/Divider
/// etc. would otherwise render with the wrong palette.
class OpeningHoursEditor extends StatefulWidget {
  final OpeningHours initial;
  final ValueChanged<OpeningHours> onChanged;
  final bool hasError;

  const OpeningHoursEditor({super.key, required this.initial, required this.onChanged, this.hasError = false});

  @override
  State<OpeningHoursEditor> createState() => _OpeningHoursEditorState();
}

class _OpeningHoursEditorState extends State<OpeningHoursEditor> {
  late bool _is24h = widget.initial.is24h;
  late Map<int, DayHours?> _schedule = Map.of(widget.initial.schedule);
  late bool _sameEveryDay = _inferSameEveryDay(widget.initial.schedule);

  bool _inferSameEveryDay(Map<int, DayHours?> schedule) {
    final openDays = schedule.values.whereType<DayHours>().toList();
    if (openDays.isEmpty) return true;
    if (openDays.length != 7) return false;
    return openDays.every((d) => d.open == openDays.first.open && d.close == openDays.first.close);
  }

  void _emit() {
    widget.onChanged(OpeningHours(is24h: _is24h, schedule: _schedule));
  }

  void _setIs24h(bool value) {
    setState(() => _is24h = value);
    _emit();
  }

  void _setSameEveryDay(bool value) {
    setState(() {
      _sameEveryDay = value;
      if (value) {
        final uniform = _schedule.values.whereType<DayHours>().firstOrNull ??
            const DayHours(open: _kDefaultOpen, close: _kDefaultClose);
        _schedule = {for (var d = 1; d <= 7; d++) d: uniform};
      }
    });
    _emit();
  }

  void _applyUniform(DayHours hours) {
    setState(() => _schedule = {for (var d = 1; d <= 7; d++) d: hours});
    _emit();
  }

  void _toggleDay(int weekday, bool open) {
    setState(() {
      _schedule[weekday] = open ? const DayHours(open: _kDefaultOpen, close: _kDefaultClose) : null;
    });
    _emit();
  }

  void _setDayHours(int weekday, DayHours hours) {
    setState(() => _schedule[weekday] = hours);
    _emit();
  }

  Future<void> _pickTime(BuildContext context, String initial, ValueChanged<String> onPicked) async {
    final parts = initial.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 9,
      minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: widget.hasError ? Border.all(color: AppColors.error, width: 1.2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.venueHours24Label,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ChatLightColors.ink),
                ),
              ),
              Switch(
                value: _is24h,
                onChanged: _setIs24h,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: ChatLightColors.cardSurface,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _is24h
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      Divider(height: 1, color: ChatLightColors.inkFaint.withValues(alpha: 0.25)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.venueHoursSameEveryDayLabel,
                              style: const TextStyle(fontSize: 14, color: ChatLightColors.ink),
                            ),
                          ),
                          Switch(
                            value: _sameEveryDay,
                            onChanged: _setSameEveryDay,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: ChatLightColors.cardSurface,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_sameEveryDay)
                        _UniformHoursRow(
                          hours: _schedule.values.whereType<DayHours>().firstOrNull ??
                              const DayHours(open: _kDefaultOpen, close: _kDefaultClose),
                          onPickOpen: () => _pickTime(
                            context,
                            _schedule.values.whereType<DayHours>().firstOrNull?.open ?? _kDefaultOpen,
                            (t) => _applyUniform(
                              DayHours(open: t, close: _schedule.values.whereType<DayHours>().firstOrNull?.close ?? _kDefaultClose),
                            ),
                          ),
                          onPickClose: () => _pickTime(
                            context,
                            _schedule.values.whereType<DayHours>().firstOrNull?.close ?? _kDefaultClose,
                            (t) => _applyUniform(
                              DayHours(open: _schedule.values.whereType<DayHours>().firstOrNull?.open ?? _kDefaultOpen, close: t),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (var weekday = 1; weekday <= 7; weekday++)
                              _DayRow(
                                label: _weekdayLabel(loc, weekday),
                                hours: _schedule[weekday],
                                onToggle: (open) => _toggleDay(weekday, open),
                                onPickOpen: () => _pickTime(
                                  context,
                                  _schedule[weekday]?.open ?? _kDefaultOpen,
                                  (t) => _setDayHours(weekday, DayHours(open: t, close: _schedule[weekday]?.close ?? _kDefaultClose)),
                                ),
                                onPickClose: () => _pickTime(
                                  context,
                                  _schedule[weekday]?.close ?? _kDefaultClose,
                                  (t) => _setDayHours(weekday, DayHours(open: _schedule[weekday]?.open ?? _kDefaultOpen, close: t)),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(AppLocalizations loc, int weekday) {
    return switch (weekday) {
      1 => loc.venueWeekdayMon,
      2 => loc.venueWeekdayTue,
      3 => loc.venueWeekdayWed,
      4 => loc.venueWeekdayThu,
      5 => loc.venueWeekdayFri,
      6 => loc.venueWeekdaySat,
      _ => loc.venueWeekdaySun,
    };
  }
}

class _UniformHoursRow extends StatelessWidget {
  final DayHours hours;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  const _UniformHoursRow({required this.hours, required this.onPickOpen, required this.onPickClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TimeChip(label: hours.open, onTap: onPickOpen)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward, size: 14, color: ChatLightColors.inkFaint),
        ),
        Expanded(child: _TimeChip(label: hours.close, onTap: onPickClose)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final DayHours? hours;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  const _DayRow({
    required this.label,
    required this.hours,
    required this.onToggle,
    required this.onPickOpen,
    required this.onPickClose,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = hours != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: GestureDetector(
              onTap: () => onToggle(!isOpen),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isOpen ? ChatLightColors.ink : ChatLightColors.inkFaint,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: isOpen
                  ? Row(
                      key: const ValueKey('open'),
                      children: [
                        Expanded(child: _TimeChip(label: hours!.open, onTap: onPickOpen, compact: true)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 12, color: ChatLightColors.inkFaint),
                        ),
                        Expanded(child: _TimeChip(label: hours!.close, onTap: onPickClose, compact: true)),
                      ],
                    )
                  : Align(
                      key: const ValueKey('closed'),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '—',
                        style: TextStyle(fontSize: 12.5, color: ChatLightColors.inkFaint),
                      ),
                    ),
            ),
          ),
          Switch(
            value: isOpen,
            onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: ChatLightColors.cardSurface,
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _TimeChip({required this.label, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: ChatLightColors.cardSurface,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time_outlined, size: compact ? 13 : 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12.5 : 14,
                fontWeight: FontWeight.w600,
                color: ChatLightColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _ElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) => index >= 0 && index < length ? this[index] : null;
}
