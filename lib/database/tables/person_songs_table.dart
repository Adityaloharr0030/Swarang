import 'package:drift/drift.dart';

import 'people_table.dart';
import 'songs_table.dart';

/// Junction table for the many-to-many relationship between People and Songs.
///
/// A unique constraint on (personId, songId) prevents duplicate assignments.
@DataClassName('PersonSongEntry')
class PersonSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(People, #id)();
  IntColumn get songId => integer().references(Songs, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {personId, songId},
      ];
}
