import 'package:flutter_test/flutter_test.dart';
import 'package:garba_song_manager/core/utils/age_calculator.dart';

void main() {
  group('AgeCalculator', () {
    test('calculates age correctly for a past birthday', () {
      final dob = DateTime(2000, 1, 15);
      final ref = DateTime(2026, 8, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 26);
    });

    test('calculates age correctly on the day before birthday', () {
      // DOB = 2000-08-30, reference = 2026-08-29 → age 25
      final dob = DateTime(2000, 8, 30);
      final ref = DateTime(2026, 8, 29);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 25);
    });

    test('calculates age correctly on birthday', () {
      // DOB = 2000-08-30, reference = 2026-08-30 → age 26
      final dob = DateTime(2000, 8, 30);
      final ref = DateTime(2026, 8, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 26);
    });

    test('calculates age correctly the day after birthday', () {
      // DOB = 2000-08-30, reference = 2026-08-31 → age 26
      final dob = DateTime(2000, 8, 30);
      final ref = DateTime(2026, 8, 31);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 26);
    });

    test('handles same day (newborn)', () {
      final dob = DateTime(2026, 8, 30);
      final ref = DateTime(2026, 8, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 0);
    });

    test('handles leap year birthday on Feb 29', () {
      final dob = DateTime(2000, 2, 29);
      // On Feb 28, 2026 → still 25
      expect(
        AgeCalculator.calculateAge(dob,
            referenceDate: DateTime(2026, 2, 28)),
        25,
      );
      // On Mar 1, 2026 → 26
      expect(
        AgeCalculator.calculateAge(dob,
            referenceDate: DateTime(2026, 3, 1)),
        26,
      );
    });

    test('returns 0 for future date of birth', () {
      final dob = DateTime(2030, 1, 1);
      final ref = DateTime(2026, 8, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 0);
    });

    test('handles very old age', () {
      final dob = DateTime(1920, 5, 15);
      final ref = DateTime(2026, 8, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 106);
    });

    test('formatAge returns correct string', () {
      final dob = DateTime(1999, 5, 14);
      final ref = DateTime(2026, 8, 30);
      expect(
          AgeCalculator.formatAge(dob, referenceDate: ref), 'Age 27');
    });

    test('birthday boundary: month same but day before', () {
      // DOB = March 15, ref = March 14 → hasn't had birthday
      final dob = DateTime(2000, 3, 15);
      final ref = DateTime(2026, 3, 14);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 25);
    });

    test('birthday boundary: month before', () {
      // DOB = August, ref = July → hasn't had birthday
      final dob = DateTime(2000, 8, 15);
      final ref = DateTime(2026, 7, 30);
      expect(AgeCalculator.calculateAge(dob, referenceDate: ref), 25);
    });
  });
}
