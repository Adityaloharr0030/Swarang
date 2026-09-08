import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/people_table.dart';
import '../tables/person_songs_table.dart';

part 'people_dao.g.dart';

/// Data Access Object for People table operations.
///
/// All database queries for people go through this DAO.
/// The UI never directly uses this — repositories wrap it.
@DriftAccessor(tables: [People, PersonSongs])
class PeopleDao extends DatabaseAccessor<AppDatabase> with _$PeopleDaoMixin {
  PeopleDao(super.db);

  /// Insert a new person. Returns the generated ID.
  Future<int> insertPerson(PeopleCompanion person) {
    return into(people).insert(person);
  }

  /// Update an existing person. Returns true if a row was updated.
  Future<bool> updatePerson(PeopleCompanion person) {
    return update(people).replace(
      Person(
        id: person.id.value,
        name: person.name.value,
        dateOfBirth: person.dateOfBirth.value,
        gender: person.gender.value,
        phoneNumber: person.phoneNumber.value,
        notes: person.notes.value,
        photoPath: person.photoPath.value,
        createdAt: person.createdAt.value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Delete a person by ID. Returns the number of rows deleted.
  Future<int> deletePerson(int id) {
    return (delete(people)..where((p) => p.id.equals(id))).go();
  }

  /// Get a single person by ID.
  Future<Person?> getPersonById(int id) {
    return (select(people)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Get all people, ordered by name.
  Future<List<Person>> getAllPeople() {
    return (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  /// Watch all people as a stream (reactive).
  Stream<List<Person>> watchAllPeople() {
    return (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  }

  /// Search people by name (case-insensitive).
  Future<List<Person>> searchByName(String query) {
    return (select(people)
          ..where((p) => p.name.lower().like('%${query.toLowerCase()}%'))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  /// Count total number of people.
  Future<int> countPeople() async {
    final count = people.id.count();
    final query = selectOnly(people)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch total number of people reactively.
  Stream<int> watchCountPeople() {
    final count = people.id.count();
    final query = selectOnly(people)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Get recently added people.
  Future<List<Person>> getRecentPeople(int limit) {
    return (select(people)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Watch recently added people reactively.
  Stream<List<Person>> watchRecentPeople(int limit) {
    return (select(people)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// Advanced filtered search with dynamic WHERE clause.
  ///
  /// All parameters are optional — only active filters are applied (AND logic).
  Future<List<Person>> advancedSearch({
    String? nameQuery,
    DateTime? minDateOfBirth,
    DateTime? maxDateOfBirth,
    String? gender,
    int? songId,
  }) async {
    if (songId != null) {
      // Need to JOIN with person_songs when filtering by song
      final query = select(people).join([
        innerJoin(
          personSongs,
          personSongs.personId.equalsExp(people.id),
        ),
      ]);

      query.where(personSongs.songId.equals(songId));

      if (nameQuery != null && nameQuery.isNotEmpty) {
        query.where(people.name.lower().like('%${nameQuery.toLowerCase()}%'));
      }
      if (minDateOfBirth != null) {
        // minDateOfBirth means max age → DOB must be >= this date
        query.where(people.dateOfBirth.isBiggerOrEqualValue(minDateOfBirth));
      }
      if (maxDateOfBirth != null) {
        // maxDateOfBirth means min age → DOB must be <= this date
        query.where(
            people.dateOfBirth.isSmallerOrEqualValue(maxDateOfBirth));
      }
      if (gender != null && gender.isNotEmpty) {
        query.where(people.gender.equals(gender));
      }

      query.orderBy([OrderingTerm.asc(people.name)]);

      final rows = await query.get();
      return rows.map((row) => row.readTable(people)).toList();
    } else {
      // Simple query without song filter
      final query = select(people);

      if (nameQuery != null && nameQuery.isNotEmpty) {
        query.where(
            (p) => p.name.lower().like('%${nameQuery.toLowerCase()}%'));
      }
      if (minDateOfBirth != null) {
        query.where((p) => p.dateOfBirth.isBiggerOrEqualValue(minDateOfBirth));
      }
      if (maxDateOfBirth != null) {
        query.where(
            (p) => p.dateOfBirth.isSmallerOrEqualValue(maxDateOfBirth));
      }
      if (gender != null && gender.isNotEmpty) {
        query.where((p) => p.gender.equals(gender));
      }

      query.orderBy([(p) => OrderingTerm.asc(p.name)]);
      return query.get();
    }
  }
}
