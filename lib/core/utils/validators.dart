/// Form validation utilities.
class Validators {
  Validators._();

  /// Validate that a name is not empty.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  /// Validate a required text field.
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate that a date of birth is provided and not in the future, and is reasonable.
  static String? validateDateOfBirth(DateTime? value) {
    if (value == null) {
      return 'Date of birth is required';
    }
    if (value.isAfter(DateTime.now())) {
      return 'Date of birth cannot be in the future';
    }
    if (value.year < 1900) {
      return 'Please enter a valid year';
    }
    return null;
  }

  /// Validate a phone number (optional, but must be valid format if provided).
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    // Allow digits, spaces, dashes, parentheses, plus sign
    final phoneRegex = RegExp(r'^[+\d][\d\s\-()]{4,20}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Validate song lyrics (required, must have content).
  static String? validateLyrics(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Lyrics are required';
    }
    return null;
  }
}
