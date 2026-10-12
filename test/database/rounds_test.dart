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

  group('RoundsDao', () {
    test('create round and fetch by id', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(
          name: 'Day 1 - Evening Aarti & Garba',
          notes: const Value('First night round'),
          date: Value(DateTime(2026, 10, 15)),
        ),
      );

      final round = await db.roundsDao.getRoundById(roundId);
      expect(round, isNotNull);
      expect(round!.name, 'Day 1 - Evening Aarti & Garba');
      expect(round.notes, 'First night round');
    });

    test('add people to round and fetch round people', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(name: 'Round 1'),
      );

      final personId1 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Kavita Joshi',
          dateOfBirth: DateTime(1996, 7, 21),
          gender: 'female',
        ),
      );
      final personId2 = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Aakash Dave',
          dateOfBirth: DateTime(1992, 3, 10),
          gender: 'male',
        ),
      );

      await db.roundsDao.addPersonToRound(roundId: roundId, personId: personId1);
      await db.roundsDao.addPersonToRound(roundId: roundId, personId: personId2);

      final people = await db.roundsDao.getPeopleForRound(roundId);
      expect(people.length, 2);
      expect(people.map((p) => p.name), containsAll(['Kavita Joshi', 'Aakash Dave']));
    });

    test('assign songs to person in round with tempo (slow/medium/fast)', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(name: 'Maha Garba Round'),
      );

      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Hiren Patel',
          dateOfBirth: DateTime(1995, 1, 1),
          gender: 'male',
        ),
      );

      final song1 = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Chogada Tara', category: const Value('Garba')),
      );
      final song2 = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Kamariya', category: const Value('Garba')),
      );

      // Assign with slow and fast tempos
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: song1,
        tempo: 'slow',
        orderIndex: 0,
      );
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: song2,
        tempo: 'fast',
        orderIndex: 1,
      );

      final details = await db.roundsDao.getSongsWithDetailsForRoundPerson(
        roundId: roundId,
        personId: personId,
      );

      expect(details.length, 2);
      expect(details[0].song.title, 'Chogada Tara');
      expect(details[0].entry.tempo, 'slow');
      expect(details[1].song.title, 'Kamariya');
      expect(details[1].entry.tempo, 'fast');

      // Update tempo from slow to medium
      await db.roundsDao.updateSongTempo(
        entryId: details[0].entry.id,
        tempo: 'medium',
      );

      final updated = await db.roundsDao.getSongsWithDetailsForRoundPerson(
        roundId: roundId,
        personId: personId,
      );
      expect(updated[0].entry.tempo, 'medium');
    });

    test('reorder songs for round person', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(name: 'Reorder Test Round'),
      );
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Sneha Shah',
          dateOfBirth: DateTime(1998, 4, 12),
          gender: 'female',
        ),
      );

      final song1 = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Song Alpha'),
      );
      final song2 = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Song Beta'),
      );

      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: song1,
        orderIndex: 0,
      );
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: song2,
        orderIndex: 1,
      );

      // Reorder so song2 is first, song1 is second
      await db.roundsDao.reorderSongsForRoundPerson(
        roundId: roundId,
        personId: personId,
        songIds: [song2, song1],
      );

      final reordered = await db.roundsDao.getSongsWithDetailsForRoundPerson(
        roundId: roundId,
        personId: personId,
      );
      expect(reordered[0].song.title, 'Song Beta');
      expect(reordered[1].song.title, 'Song Alpha');
    });

    test('delete round and cascades', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(name: 'Round to Delete'),
      );
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Test Singer',
          dateOfBirth: DateTime(1990, 1, 1),
          gender: 'male',
        ),
      );
      await db.roundsDao.addPersonToRound(roundId: roundId, personId: personId);

      await db.roundsDao.deleteRoundData(roundId);
      await db.roundsDao.deleteRound(roundId);

      final round = await db.roundsDao.getRoundById(roundId);
      expect(round, isNull);
      final people = await db.roundsDao.getPeopleForRound(roundId);
      expect(people, isEmpty);
    });

    test('auto-sort songs by tempo (slow -> medium -> fast) and watch tempo counts', () async {
      final roundId = await db.roundsDao.insertRound(
        RoundsCompanion.insert(name: 'Tempo Progression Round'),
      );
      final personId = await db.peopleDao.insertPerson(
        PeopleCompanion.insert(
          name: 'Kinjal Dave',
          dateOfBirth: DateTime(1999, 11, 20),
          gender: 'female',
        ),
      );

      final songFast = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Sanedo (Fast)'),
      );
      final songSlow = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Tara Vina Shyam (Slow)'),
      );
      final songMed = await db.songsDao.insertSong(
        SongsCompanion.insert(title: 'Dholida (Med)'),
      );

      // Add out of order: Fast (0), Slow (1), Medium (2)
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: songFast,
        tempo: 'fast',
        orderIndex: 0,
      );
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: songSlow,
        tempo: 'slow',
        orderIndex: 1,
      );
      await db.roundsDao.addSongToRoundPerson(
        roundId: roundId,
        personId: personId,
        songId: songMed,
        tempo: 'medium',
        orderIndex: 2,
      );

      // Verify tempo counts
      final counts = await db.roundsDao.watchTempoCountsInRound(roundId).first;
      expect(counts['slow'], 1);
      expect(counts['medium'], 1);
      expect(counts['fast'], 1);

      // Trigger auto-sort by Garba tempo
      await db.roundsDao.sortSongsByTempo(
        roundId: roundId,
        personId: personId,
      );

      final sorted = await db.roundsDao.getSongsWithDetailsForRoundPerson(
        roundId: roundId,
        personId: personId,
      );

      // Expected order: Slow first, Medium second, Fast third
      expect(sorted[0].song.title, 'Tara Vina Shyam (Slow)');
      expect(sorted[0].entry.tempo, 'slow');
      expect(sorted[1].song.title, 'Dholida (Med)');
      expect(sorted[1].entry.tempo, 'medium');
      expect(sorted[2].song.title, 'Sanedo (Fast)');
      expect(sorted[2].entry.tempo, 'fast');
    });
  });
}
