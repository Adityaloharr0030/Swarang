import 'package:drift/drift.dart';

import 'people_table.dart';
import 'rounds_table.dart';
import 'songs_table.dart';

/// Round-Person-Songs table — a song assigned to a person for a specific round.
///
/// [tempo] can be: 'fast', 'medium', or 'slow'.
/// [orderIndex] controls the playback order within a person's song list for this round.
@DataClassName('RoundSongEntry')
class RoundSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get roundId => integer().references(Rounds, #id)();
  IntColumn get personId => integer().references(People, #id)();
  IntColumn get songId => integer().references(Songs, #id)();

  /// Tempo: 'fast', 'medium', or 'slow'
  TextColumn get tempo => text().withDefault(const Constant('medium'))();

  /// Order within this person's song list in this round
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {roundId, personId, songId},
      ];
}
