import 'package:drift/drift.dart';

/// Rounds table — stores a named performance round (e.g. "Night 1 Round 2").
@DataClassName('Round')
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
