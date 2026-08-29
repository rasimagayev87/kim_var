import 'package:flutter_test/flutter_test.dart';
import 'package:peakpin/core/utils/age_calculator.dart';

void main() {
  group('calculateAge', () {
    test('exact birthday today counts the new age', () {
      final now = DateTime.now();
      final birthDate = DateTime(now.year - 18, now.month, now.day);
      expect(calculateAge(birthDate), 18);
    });

    test('one day before the birthday still counts the old age', () {
      final now = DateTime.now();
      final birthDate = DateTime(now.year - 18, now.month, now.day).add(const Duration(days: 1));
      expect(calculateAge(birthDate), 17);
    });

    test('one day after the birthday already counts the new age', () {
      final now = DateTime.now();
      final birthDate = DateTime(now.year - 18, now.month, now.day).subtract(const Duration(days: 1));
      expect(calculateAge(birthDate), 18);
    });

    test('a future birth date yields a negative age rather than throwing', () {
      final now = DateTime.now();
      final future = DateTime(now.year + 1, now.month, now.day);
      expect(() => calculateAge(future), returnsNormally);
      expect(calculateAge(future), lessThan(0));
    });

    test('leap-year (Feb 29) birth date is handled without throwing', () {
      // Compare against a fixed, known leap year rather than `now.year`,
      // since "18 years before whatever year the test happens to run in"
      // isn't guaranteed to itself be a leap year.
      final birthDate = DateTime(2004, 2, 29);
      expect(() => calculateAge(birthDate), returnsNormally);
    });
  });
}
