import 'package:drift/drift.dart';

/// Songs table — stores Garba songs with full lyrics, photos, and PDFs.
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1)();
  TextColumn get lyrics => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Comma-separated local file paths for attached page photos.
  TextColumn get photoPaths => text().nullable()();

  /// Local file path for an attached PDF document.
  TextColumn get pdfPath => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
