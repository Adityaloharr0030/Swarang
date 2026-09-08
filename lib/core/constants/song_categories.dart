/// Default song categories.
///
/// These are not hard-coded into the database schema —
/// they serve as suggestions in the UI dropdown.
/// New categories can be added here without any migration.
class SongCategories {
  SongCategories._();

  static const List<String> defaults = [
    'Traditional',
    'Garba',
    'Dandiya',
    'Devotional',
    'Fast',
    'Slow',
    'Other',
  ];
}
