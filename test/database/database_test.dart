import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garba_song_manager/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PeopleDao', () {
    test('insert and retrieve person', () async {
      final id = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Rajesh Patel',
          dateOfBirth: DateTime(1994, 5, 14),
          gender: 'male',
        ),
      );

      final person = await db.peopleDao.getPersonById(id);
      expect(person, isNotNull);
      expect(person!.name, 'Rajesh Patel');
      expect(person.gender, 'male');
    });

    test('get all people returns sorted by name', () async {
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Zara Shah',
          dateOfBirth: DateTime(1990, 1, 1),
          gender: 'female',
        ),
      );
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Anita Patel',
          dateOfBirth: DateTime(1995, 6, 15),
          gender: 'female',
        ),
      );

      final people = await db.peopleDao.getAllPeople();
      expect(people.length, 2);
      expect(people[0].name, 'Anita Patel');
      expect(people[1].name, 'Zara Shah');
    });

    test('search by name', () async {
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Ramesh Patel',
          dateOfBirth: DateTime(1990, 1, 1),
          gender: 'male',
        ),
      );
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Ramesh Shah',
          dateOfBirth: DateTime(1992, 3, 20),
          gender: 'male',
        ),
      );
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Anita Desai',
          dateOfBirth: DateTime(1995, 6, 15),
          gender: 'female',
        ),
      );

      final results = await db.peopleDao.searchByName('Ramesh');
      expect(results.length, 2);
    });

    test('delete person', () async {
      final id = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test Person',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );

      await db.peopleDao.deletePerson(id);
      final person = await db.peopleDao.getPersonById(id);
      expect(person, isNull);
    });

    test('count people', () async {
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Person 1',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Person 2',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'female',
        ),
      );

      final count = await db.peopleDao.countPeople();
      expect(count, 2);
    });
  });

  group('SongsDao', () {
    test('insert and retrieve song', () async {
      final id = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Pankhida Tu Udi Jaje',
          lyrics: const Value('Pankhida tu udi jaje...'),
          category: const Value('Garba'),
        ),
      );

      final song = await db.songsDao.getSongById(id);
      expect(song, isNotNull);
      expect(song!.title, 'Pankhida Tu Udi Jaje');
      expect(song.category, 'Garba');
    });

    test('search by title', () async {
      await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Tara Vina Shyam',
          lyrics: const Value('Tara vina...'),
        ),
      );
      await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Pankhida',
          lyrics: const Value('Pankhida...'),
        ),
      );

      final results = await db.songsDao.searchByTitle('Tara');
      expect(results.length, 1);
      expect(results[0].title, 'Tara Vina Shyam');
    });

    test('filter by category', () async {
      await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Song 1',
          lyrics: const Value('Lyrics...'),
          category: const Value('Garba'),
        ),
      );
      await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Song 2',
          lyrics: const Value('Lyrics...'),
          category: const Value('Dandiya'),
        ),
      );

      final results = await db.songsDao.filterByCategory('Garba');
      expect(results.length, 1);
      expect(results[0].title, 'Song 1');
    });
  });

  group('PersonSongsDao', () {
    test('assign song to person', () async {
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test Person',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final songId = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Test Song',
          lyrics: const Value('Test lyrics...'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId,
      );

      final songs = await db.personSongsDao.getSongsForPerson(personId);
      expect(songs.length, 1);
      expect(songs[0].title, 'Test Song');
    });

    test('get people for song', () async {
      final personId1 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Person 1',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final personId2 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Person 2',
          dateOfBirth: DateTime(1995, 6, 15),
          gender: 'female',
        ),
      );
      final songId = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Shared Song',
          lyrics: const Value('Shared lyrics...'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId1,
        songId: songId,
      );
      await db.personSongsDao.assignSongToPerson(
        personId: personId2,
        songId: songId,
      );

      final people = await db.personSongsDao.getPeopleForSong(songId);
      expect(people.length, 2);
    });

    test('prevent duplicate assignment', () async {
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final songId = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Test Song',
          lyrics: const Value('Lyrics...'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId,
      );

      // Second assignment should throw
      expect(
        () => db.personSongsDao.assignSongToPerson(
          personId: personId,
          songId: songId,
        ),
        throwsA(anything),
      );
    });

    test('remove assignment', () async {
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final songId = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Test Song',
          lyrics: const Value('Lyrics...'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId,
      );
      await db.personSongsDao.removeSongFromPerson(
        personId: personId,
        songId: songId,
      );

      final songs = await db.personSongsDao.getSongsForPerson(personId);
      expect(songs, isEmpty);
    });

    test('count assignments', () async {
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final songId1 = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Song 1',
          lyrics: const Value('Lyrics 1...'),
        ),
      );
      final songId2 = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Song 2',
          lyrics: const Value('Lyrics 2...'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId1,
      );
      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId2,
      );

      final count = await db.personSongsDao.countSongsForPerson(personId);
      expect(count, 2);
    });

    test('assignment exists check', () async {
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      final songId = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Test Song',
          lyrics: const Value('Lyrics...'),
        ),
      );

      expect(
        await db.personSongsDao.assignmentExists(
          personId: personId,
          songId: songId,
        ),
        false,
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId,
        songId: songId,
      );

      expect(
        await db.personSongsDao.assignmentExists(
          personId: personId,
          songId: songId,
        ),
        true,
      );
    });
  });

  group('Advanced Search', () {
    late int personId1, personId3;
    // ignore: unused_local_variable
    late int personId2;
    late int songId1;

    setUp(() async {
      personId1 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Priya Patel',
          dateOfBirth: DateTime(1998, 3, 15), // ~28
          gender: 'female',
        ),
      );
      personId2 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Raj Kumar',
          dateOfBirth: DateTime(1990, 7, 20), // ~36
          gender: 'male',
        ),
      );
      personId3 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Anita Shah',
          dateOfBirth: DateTime(2001, 11, 5), // ~24
          gender: 'female',
        ),
      );

      songId1 = await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Pankhida Tu Udi Jaje',
          lyrics: const Value('Pankhida...'),
          category: const Value('Garba'),
        ),
      );

      await db.personSongsDao.assignSongToPerson(
        personId: personId1,
        songId: songId1,
      );
      await db.personSongsDao.assignSongToPerson(
        personId: personId3,
        songId: songId1,
      );
    });

    test('filter by gender = female', () async {
      final results =
          await db.peopleDao.advancedSearch(gender: 'female');
      expect(results.length, 2); // Priya, Anita
    });

    test('filter by song', () async {
      final results =
          await db.peopleDao.advancedSearch(songId: songId1);
      expect(results.length, 2); // Priya, Anita
    });

    test('combined: gender + song', () async {
      final results = await db.peopleDao.advancedSearch(
        gender: 'female',
        songId: songId1,
      );
      expect(results.length, 2); // Priya, Anita (both female + song)
    });

    test('filter by name', () async {
      final results =
          await db.peopleDao.advancedSearch(nameQuery: 'Patel');
      expect(results.length, 1);
      expect(results[0].name, 'Priya Patel');
    });
  });

  group('Backup data', () {
    test('delete all data clears everything', () async {
      await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test',
          dateOfBirth: DateTime(2000, 1, 1),
          gender: 'male',
        ),
      );
      await db.songsDao.insertSong(
        SongsCompanion.insert(
          title: 'Song',
          lyrics: const Value('Lyrics...'),
        ),
      );

      await db.deleteAllData();

      expect(await db.peopleDao.countPeople(), 0);
      expect(await db.songsDao.countSongs(), 0);
    });
  });
}
