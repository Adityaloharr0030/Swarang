/// Gender options for people in the system.
enum Gender {
  male('Male'),
  female('Female'),
  other('Other'),
  preferNotToSay('Prefer not to say');

  const Gender(this.displayName);

  /// Human-readable display name.
  final String displayName;

  /// Parse a gender from its stored string value.
  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (g) => g.name == value || g.displayName == value,
      orElse: () => Gender.other,
    );
  }
}
