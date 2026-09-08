import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/people_table.dart';
import '../tables/person_songs_table.dart';
import '../tables/songs_table.dart';

part 'person_songs_dao.g.dart';

/// Data Access Object for the Person-Song junction table.
///
/// Manages the many-to-many relationships between People and Songs.
@DriftAccessor(tables: [PersonSongs, People, Songs])
class PersonSongsDao extends DatabaseAccessor<AppDatabase>
    with _$PersonSongsDaoMixin {
  PersonSongsDao(super.db);

  /// Assign a song to a person.
  ///
  /// Returns the generated assignment ID.
  /// Throws if the relationship already exists (unique constraint).
  Future<int> assignSongToPerson({
    required int personId,
    required int songId,
    String? notes,
  }) {
    return into(personSongs).insert(
      PersonSongsCompanion.insert(
        personId: personId,
        songId: songId,
        notes: Value(notes),
      ),
    );
  }

  /// Remove a song assignment from a person.
  Future<int> removeSongFromPerson({
    required int personId,
    required int songId,
  }) {
    return (delete(personSongs)
          ..where(
              (ps) => ps.personId.equals(personId) & ps.songId.equals(songId)))
        .go();
  }

  /// Get all songs assigned to a person.
  Future<List<Song>> getSongsForPerson(int personId) async {
    final query = select(songs).join([
      innerJoin(
        personSongs,
        personSongs.songId.equalsExp(songs.id),
      ),
    ]);
    query.where(personSongs.personId.equals(personId));
    query.orderBy([OrderingTerm.asc(songs.title)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(songs)).toList();
  }

  /// Watch songs for a person reactively.
  Stream<List<Song>> watchSongsForPerson(int personId) {
    final query = select(songs).join([
      innerJoin(
        personSongs,
        personSongs.songId.equalsExp(songs.id),
      ),
    ]);
    query.where(personSongs.personId.equals(personId));
    query.orderBy([OrderingTerm.asc(songs.title)]);

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(songs)).toList(),
        );
  }

  /// Get all people assigned to a song.
  Future<List<Person>> getPeopleForSong(int songId) async {
    final query = select(people).join([
      innerJoin(
        personSongs,
        personSongs.personId.equalsExp(people.id),
      ),
    ]);
    query.where(personSongs.songId.equals(songId));
    query.orderBy([OrderingTerm.asc(people.name)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(people)).toList();
  }

  /// Watch people for a song reactively.
  Stream<List<Person>> watchPeopleForSong(int songId) {
    final query = select(people).join([
      innerJoin(
        personSongs,
        personSongs.personId.equalsExp(people.id),
      ),
    ]);
    query.where(personSongs.songId.equals(songId));
    query.orderBy([OrderingTerm.asc(people.name)]);

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(people)).toList(),
        );
  }

  /// Count total number of assignments.
  Future<int> countAssignments() async {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch total number of assignments reactively.
  Stream<int> watchCountAssignments() {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Count songs for a specific person.
  Future<int> countSongsForPerson(int personId) async {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)
      ..addColumns([count])
      ..where(personSongs.personId.equals(personId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch song count for a specific person reactively.
  Stream<int> watchCountSongsForPerson(int personId) {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)
      ..addColumns([count])
      ..where(personSongs.personId.equals(personId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Count people for a specific song.
  Future<int> countPeopleForSong(int songId) async {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)
      ..addColumns([count])
      ..where(personSongs.songId.equals(songId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch people count for a specific song reactively.
  Stream<int> watchCountPeopleForSong(int songId) {
    final count = personSongs.id.count();
    final query = selectOnly(personSongs)
      ..addColumns([count])
      ..where(personSongs.songId.equals(songId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Get all assignment entries (for backup).
  Future<List<PersonSongEntry>> getAllAssignments() {
    return select(personSongs).get();
  }

  /// Delete all assignments for a person (used before deleting the person).
  Future<int> deleteAssignmentsForPerson(int personId) {
    return (delete(personSongs)
          ..where((ps) => ps.personId.equals(personId)))
        .go();
  }

  /// Delete all assignments for a song (used before deleting the song).
  Future<int> deleteAssignmentsForSong(int songId) {
    return (delete(personSongs)
          ..where((ps) => ps.songId.equals(songId)))
        .go();
  }

  /// Check if a specific assignment already exists.
  Future<bool> assignmentExists({
    required int personId,
    required int songId,
  }) async {
    final result = await (select(personSongs)
          ..where(
              (ps) => ps.personId.equals(personId) & ps.songId.equals(songId)))
        .getSingleOrNull();
    return result != null;
  }
}
