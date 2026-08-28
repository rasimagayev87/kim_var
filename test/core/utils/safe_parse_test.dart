import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/utils/safe_parse.dart';

enum _TestEnum { alpha, beta }

void main() {
  group('safeString', () {
    test('returns the value when it is a String', () => expect(safeString('hi'), 'hi'));
    test('falls back on null', () => expect(safeString(null), ''));
    test('falls back on wrong type', () => expect(safeString(42), ''));
    test('falls back on custom default', () => expect(safeString(null, 'x'), 'x'));
  });

  group('safeInt', () {
    test('returns int as-is', () => expect(safeInt(5), 5));
    test('converts a double', () => expect(safeInt(5.9), 5));
    test('parses a numeric string', () => expect(safeInt('7'), 7));
    test('falls back on unparsable string', () => expect(safeInt('not a number'), 0));
    test('falls back on null', () => expect(safeInt(null), 0));
  });

  group('safeDouble', () {
    test('returns double as-is', () => expect(safeDouble(1.5), 1.5));
    test('converts an int', () => expect(safeDouble(3), 3.0));
    test('parses a numeric string', () => expect(safeDouble('2.5'), 2.5));
    test('falls back on unparsable string', () => expect(safeDouble('nope'), 0));
  });

  group('safeBool', () {
    test('returns bool as-is', () => expect(safeBool(true), true));
    test('falls back on null', () => expect(safeBool(null), false));
    test('falls back on wrong type', () => expect(safeBool('true'), false));
  });

  group('safeList', () {
    test('converts every element', () {
      expect(safeList<int>([1, 2, 3], (e) => e as int), [1, 2, 3]);
    });

    test('a single malformed element is dropped, not the whole list', () {
      final result = safeList<int>([1, 'bad', 3], (e) => e as int);
      expect(result, [1, 3]);
    });

    test('falls back to an empty list when the input is not a List', () {
      expect(safeList<int>(null, (e) => e as int), <int>[]);
      expect(safeList<int>('not a list', (e) => e as int), <int>[]);
    });
  });

  group('safeEnum', () {
    test('matches by name', () {
      expect(safeEnum('beta', _TestEnum.values, _TestEnum.alpha), _TestEnum.beta);
    });

    test('falls back on an unrecognized name', () {
      expect(safeEnum('unknown_future_value', _TestEnum.values, _TestEnum.alpha), _TestEnum.alpha);
    });

    test('falls back on null', () {
      expect(safeEnum(null, _TestEnum.values, _TestEnum.alpha), _TestEnum.alpha);
    });
  });

  group('safeTimestamp', () {
    test('converts a Timestamp to DateTime', () {
      final now = DateTime.now();
      expect(safeTimestamp(Timestamp.fromDate(now))?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('returns null for anything else', () {
      expect(safeTimestamp(null), null);
      expect(safeTimestamp('2024-01-01'), null);
    });
  });
}
