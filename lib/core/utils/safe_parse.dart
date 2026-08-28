import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared defensive-parsing helpers for reading Firestore/JSON `dynamic`
/// values — every one takes a raw value plus a default and never throws,
/// codifying the `as Type? ?? default` idiom already used successfully in
/// this codebase's hand-written parsers (`Post`, `AppNotification`,
/// `ChatMessage`) into one reusable place instead of re-deriving it ad hoc
/// per entity. A missing field, a wrong type, or a genuinely corrupted
/// value all degrade to [fallback] rather than crashing the caller.

String safeString(dynamic value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int safeInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double safeDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool safeBool(dynamic value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

/// Parses a raw list, converting each element with [convert] — an
/// element that throws inside [convert] is skipped rather than failing
/// the whole list, matching the per-item isolation used at the
/// repository level for Firestore query results.
List<T> safeList<T>(dynamic value, T Function(dynamic element) convert) {
  if (value is! List) return const [];
  final result = <T>[];
  for (final element in value) {
    try {
      result.add(convert(element));
    } catch (_) {
      // One malformed element doesn't take down the rest of the list.
    }
  }
  return result;
}

/// Looks up [value] among [values] by name, falling back to
/// [fallback] for anything unrecognized — the safe equivalent of
/// `values.byName(value)`, which throws on an unknown string.
T safeEnum<T extends Enum>(dynamic value, List<T> values, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

DateTime? safeTimestamp(dynamic value) {
  return value is Timestamp ? value.toDate() : null;
}
