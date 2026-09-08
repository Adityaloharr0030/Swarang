import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../database/app_database.dart';
import '../../../../database/daos/people_dao.dart';
import '../../../../database/daos/person_songs_dao.dart';

/// Provider for the application database singleton.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for PeopleDao.
final peopleDaoProvider = Provider<PeopleDao>((ref) {
  return ref.watch(databaseProvider).peopleDao;
});

/// Provider for PersonSongsDao.
final personSongsDaoProvider = Provider<PersonSongsDao>((ref) {
  return ref.watch(databaseProvider).personSongsDao;
});

/// Watches all people reactively.
final allPeopleProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(peopleDaoProvider).watchAllPeople();
});

/// Gets a single person by ID.
final personByIdProvider =
    FutureProvider.family<Person?, int>((ref, id) async {
  return ref.watch(peopleDaoProvider).getPersonById(id);
});

/// Gets the song count for a specific person.
final songCountForPersonProvider =
    FutureProvider.family<int, int>((ref, personId) async {
  return ref.watch(personSongsDaoProvider).countSongsForPerson(personId);
});

/// Gets recently added people.
final recentPeopleProvider =
    StreamProvider.family<List<Person>, int>((ref, limit) {
  return ref.watch(peopleDaoProvider).watchRecentPeople(limit);
});

/// People count.
final peopleCountProvider = StreamProvider<int>((ref) {
  return ref.watch(peopleDaoProvider).watchCountPeople();
});

/// Notifier for people list search/filter state.
class PeopleSearchNotifier extends StateNotifier<String> {
  PeopleSearchNotifier() : super('');

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final peopleSearchProvider =
    StateNotifierProvider<PeopleSearchNotifier, String>((ref) {
  return PeopleSearchNotifier();
});

/// Filtered people based on search query.
final filteredPeopleProvider = FutureProvider<List<Person>>((ref) async {
  final query = ref.watch(peopleSearchProvider);
  final dao = ref.watch(peopleDaoProvider);

  if (query.isEmpty) {
    return dao.getAllPeople();
  }
  return dao.searchByName(query);
});

/// Creates a new person.
Future<int> createPerson(WidgetRef ref, PeopleCompanion person) async {
  final dao = ref.read(peopleDaoProvider);
  final id = await dao.insertPerson(person);
  // Manual invalidation no longer strictly needed for reactive streams, 
  // but we keep it for filtered list if it's still a FutureProvider.
  ref.invalidate(allPeopleProvider);
  return id;
}

/// Updates an existing person.
Future<void> updatePerson(WidgetRef ref, PeopleCompanion person) async {
  final dao = ref.read(peopleDaoProvider);
  await dao.updatePerson(person);
  ref.invalidate(allPeopleProvider);
  ref.invalidate(personByIdProvider(person.id.value));
}

/// Deletes a person and their song assignments.
Future<void> deletePerson(WidgetRef ref, int personId) async {
  final personSongsDao = ref.read(personSongsDaoProvider);
  final peopleDao = ref.read(peopleDaoProvider);

  await personSongsDao.deleteAssignmentsForPerson(personId);
  await peopleDao.deletePerson(personId);

  ref.invalidate(allPeopleProvider);
}
