/// Calculates age from a date of birth.
///
/// This correctly handles birthday boundaries:
/// - DOB = 2000-08-30, today = 2026-08-29 → age 25
/// - DOB = 2000-08-30, today = 2026-08-30 → age 26
class AgeCalculator {
  AgeCalculator._();

  /// Calculate the current age in years from [dateOfBirth].
  ///
  /// Uses [referenceDate] for testability; defaults to [DateTime.now].
  static int calculateAge(DateTime dateOfBirth, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    int age = now.year - dateOfBirth.year;

    // If the birthday hasn't occurred yet this year, subtract 1.
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }

    return age < 0 ? 0 : age;
  }

  /// Format a date of birth for display.
  static String formatAge(DateTime dateOfBirth, {DateTime? referenceDate}) {
    final age = calculateAge(dateOfBirth, referenceDate: referenceDate);
    return 'Age $age';
  }
}
