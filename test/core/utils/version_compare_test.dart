import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/utils/version_compare.dart';

void main() {
  group('compareVersions', () {
    test('1.0.0 < 1.0.1', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('1.9.0 < 1.10.0 — the whole reason this exists over string comparison', () {
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
    });

    test('2.0.0 > 1.99.99', () {
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('equal versions compare as 0', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('malformed version segments fail safe to 0, never throw', () {
      expect(() => compareVersions('1.x.0', '1.0.0'), returnsNormally);
      expect(compareVersions('1.x.0', '1.0.0'), 0);
    });

    test('empty string fails safe, never throws', () {
      expect(() => compareVersions('', '1.0.0'), returnsNormally);
      expect(compareVersions('', '1.0.0'), lessThan(0));
    });

    test('differing segment counts compare correctly (missing segments as 0)', () {
      expect(compareVersions('1.2', '1.2.1'), lessThan(0));
      expect(compareVersions('1.2.0', '1.2'), 0);
    });
  });
}
