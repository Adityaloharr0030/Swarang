import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/people_table.dart';
import '../tables/round_people_table.dart';
import '../tables/round_songs_table.dart';
import '../tables/rounds_table.dart';
import '../tables/songs_table.dart';

part 'rounds_dao.g.dart';

/// Data model for a round song entry with full song & optional person info.
class RoundSongWithDetails {
  final RoundSongEntry entry;
  final Song song;
  final Person? person;

  RoundSongWithDetails({
    required this.entry,
    required this.song,
    this.person,
  });
}

/// Data model representing a song's usage in a specific round with tempo info.
class SongRoundUsage {
  final Round round;
  final RoundSongEntry entry;

  const SongRoundUsage({
    required this.round,
    required this.entry,
  });
}

/// Data Access Object for Rounds, RoundPeople, and RoundSongs.
@DriftAccessor(tables: [Rounds, RoundPeople, RoundSongs, People, Songs])
class RoundsDao extends DatabaseAccessor<AppDatabase>
    with _$RoundsDaoMixin {
  RoundsDao(super.db);

  // ── Rounds CRUD ───────────────────────────────────────────────────────────

  Future<int> insertRound(RoundsCompanion round) =>
      into(rounds).insert(round);

  Future<bool> updateRound(RoundsCompanion round) =>
      update(rounds).replace(
        Round(
          id: round.id.value,
          name: round.name.value,
          notes: round.notes.value,
          date: round.date.value,
          createdAt: round.createdAt.value,
          updatedAt: DateTime.now(),
        ),
      );

  Future<int> deleteRound(int id) =>
      (delete(rounds)..where((r) => r.id.equals(id))).go();

  Future<Round?> getRoundById(int id) =>
      (select(rounds)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<Round>> getAllRounds() =>
      (select(rounds)
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .get();

  Stream<List<Round>> watchAllRounds() =>
      (select(rounds)
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .watch();

  // ── Round People ──────────────────────────────────────────────────────────

  Future<int> addPersonToRound({
    required int roundId,
    required int personId,
  }) =>
      into(roundPeople).insert(
        RoundPeopleCompanion.insert(roundId: roundId, personId: personId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> removePersonFromRound({
    required int roundId,
    required int personId,
  }) =>
      (delete(roundPeople)
            ..where(
                (rp) => rp.roundId.equals(roundId) & rp.personId.equals(personId)))
          .go();

  Future<List<Person>> getPeopleForRound(int roundId) async {
    final query = select(people).join([
      innerJoin(roundPeople, roundPeople.personId.equalsExp(people.id)),
    ]);
    query.where(roundPeople.roundId.equals(roundId));
    query.orderBy([OrderingTerm.asc(people.name)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(people)).toList();
  }

  Stream<List<Person>> watchPeopleForRound(int roundId) {
    final query = select(people).join([
      innerJoin(roundPeople, roundPeople.personId.equalsExp(people.id)),
    ]);
    query.where(roundPeople.roundId.equals(roundId));
    query.orderBy([OrderingTerm.asc(people.name)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(people)).toList());
  }

  // ── Round Songs (Direct Round Song Association) ─────────────────────────

  /// Add a song directly to a round (no person needed).
  Future<int> addSongToRound({
    required int roundId,
    required int songId,
    String tempo = 'medium',
    int orderIndex = 0,
  }) =>
      into(roundSongs).insert(
        RoundSongsCompanion.insert(
          roundId: roundId,
          songId: songId,
          tempo: Value(tempo),
          orderIndex: Value(orderIndex),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Remove a song directly from a round.
  Future<int> removeSongFromRound({
    required int roundId,
    required int songId,
  }) =>
      (delete(roundSongs)
            ..where((rs) =>
                rs.roundId.equals(roundId) &
                rs.songId.equals(songId)))
          .go();

  /// Reorder songs within a round.
  Future<void> reorderSongsForRound({
    required int roundId,
    required List<int> songIds, // new ordered list of song IDs
  }) async {
    for (var i = 0; i < songIds.length; i++) {
      await (update(roundSongs)
            ..where((rs) =>
                rs.roundId.equals(roundId) &
                rs.songId.equals(songIds[i])))
          .write(RoundSongsCompanion(orderIndex: Value(i)));
    }
  }

  /// Get all songs for a round ordered by orderIndex.
  Future<List<RoundSongEntry>> getSongsForRound(int roundId) =>
      (select(roundSongs)
            ..where((rs) => rs.roundId.equals(roundId))
            ..orderBy([(rs) => OrderingTerm.asc(rs.orderIndex)]))
          .get();

  /// Get all songs with song details for a round.
  Future<List<RoundSongWithDetails>> getSongsWithDetailsForRound(int roundId) {
    final query = select(roundSongs).join([
      innerJoin(songs, songs.id.equalsExp(roundSongs.songId)),
    ]);
    query.where(roundSongs.roundId.equals(roundId));
    query.orderBy([OrderingTerm.asc(roundSongs.orderIndex)]);
    return query.get().then((rows) => rows
        .map((r) => RoundSongWithDetails(
              entry: r.readTable(roundSongs),
              song: r.readTable(songs),
            ))
        .toList());
  }

  /// Watch all songs with song details for a round.
  Stream<List<RoundSongWithDetails>> watchSongsWithDetailsForRound(int roundId) {
    final query = select(roundSongs).join([
      innerJoin(songs, songs.id.equalsExp(roundSongs.songId)),
    ]);
    query.where(roundSongs.roundId.equals(roundId));
    query.orderBy([OrderingTerm.asc(roundSongs.orderIndex)]);
    return query.watch().map((rows) => rows
        .map((r) => RoundSongWithDetails(
              entry: r.readTable(roundSongs),
              song: r.readTable(songs),
            ))
        .toList());
  }

  /// Check if a song already exists in a round.
  Future<bool> songExistsInRound({
    required int roundId,
    required int songId,
  }) async {
    final result = await (select(roundSongs)
          ..where((rs) =>
              rs.roundId.equals(roundId) &
              rs.songId.equals(songId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Sort all songs in a round in classic Garba progression:
  /// Slow (2-Taali) -> Medium (3-Taali) -> Fast (Titodo / Climax).
  Future<void> sortSongsByTempoForRound(int roundId) async {
    final entries = await getSongsForRound(roundId);
    int tempoRank(String t) {
      switch (t.toLowerCase()) {
        case 'slow':
          return 0;
        case 'medium':
          return 1;
        case 'fast':
          return 2;
        default:
          return 1;
      }
    }

    entries.sort((a, b) {
      final rankDiff = tempoRank(a.tempo).compareTo(tempoRank(b.tempo));
      if (rankDiff != 0) return rankDiff;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    for (var i = 0; i < entries.length; i++) {
      await (update(roundSongs)..where((rs) => rs.id.equals(entries[i].id)))
          .write(RoundSongsCompanion(orderIndex: Value(i)));
    }
  }

  /// Get all rounds where a specific song is used.
  Future<List<SongRoundUsage>> getRoundsForSong(int songId) {
    final query = select(roundSongs).join([
      innerJoin(rounds, rounds.id.equalsExp(roundSongs.roundId)),
    ]);
    query.where(roundSongs.songId.equals(songId));
    query.orderBy([OrderingTerm.asc(rounds.createdAt)]);
    return query.get().then((rows) => rows
        .map((r) => SongRoundUsage(
              round: r.readTable(rounds),
              entry: r.readTable(roundSongs),
            ))
        .toList());
  }

  /// Watch all rounds where a specific song is used.
  Stream<List<SongRoundUsage>> watchRoundsForSong(int songId) {
    final query = select(roundSongs).join([
      innerJoin(rounds, rounds.id.equalsExp(roundSongs.roundId)),
    ]);
    query.where(roundSongs.songId.equals(songId));
    query.orderBy([OrderingTerm.asc(rounds.createdAt)]);
    return query.watch().map((rows) => rows
        .map((r) => SongRoundUsage(
              round: r.readTable(rounds),
              entry: r.readTable(roundSongs),
            ))
        .toList());
  }

  /// Watch all song usages across all rounds mapped by songId.
  Stream<Map<int, List<SongRoundUsage>>> watchAllSongRoundUsages() {
    final query = select(roundSongs).join([
      innerJoin(rounds, rounds.id.equalsExp(roundSongs.roundId)),
    ]);
    query.orderBy([OrderingTerm.asc(rounds.createdAt)]);
    return query.watch().map((rows) {
      final map = <int, List<SongRoundUsage>>{};
      for (final r in rows) {
        final usage = SongRoundUsage(
          round: r.readTable(rounds),
          entry: r.readTable(roundSongs),
        );
        map.putIfAbsent(usage.entry.songId, () => []).add(usage);
      }
      return map;
    });
  }

  // ── Round-Person Songs (Legacy Person Association) ───────────────────────────

  /// Add a song to a person in a round (with tempo and order).
  Future<int> addSongToRoundPerson({
    required int roundId,
    required int personId,
    required int songId,
    String tempo = 'medium',
    int orderIndex = 0,
  }) =>
      into(roundSongs).insert(
        RoundSongsCompanion.insert(
          roundId: roundId,
          personId: Value(personId),
          songId: songId,
          tempo: Value(tempo),
          orderIndex: Value(orderIndex),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> removeSongFromRoundPerson({
    required int roundId,
    required int personId,
    required int songId,
  }) =>
      (delete(roundSongs)
            ..where((rs) =>
                rs.roundId.equals(roundId) &
                rs.personId.equals(personId) &
                rs.songId.equals(songId)))
          .go();

  Future<void> updateSongTempo({
    required int entryId,
    required String tempo,
  }) async {
    await (update(roundSongs)..where((rs) => rs.id.equals(entryId)))
        .write(RoundSongsCompanion(tempo: Value(tempo)));
  }

  Future<void> reorderSongsForRoundPerson({
    required int roundId,
    required int personId,
    required List<int> songIds, // new ordered list
  }) async {
    for (var i = 0; i < songIds.length; i++) {
      await (update(roundSongs)
            ..where((rs) =>
                rs.roundId.equals(roundId) &
                rs.personId.equals(personId) &
                rs.songId.equals(songIds[i])))
          .write(RoundSongsCompanion(orderIndex: Value(i)));
    }
  }

  /// Get all song entries for a specific person in a round.
  Future<List<RoundSongEntry>> getSongsForRoundPerson({
    required int roundId,
    required int personId,
  }) =>
      (select(roundSongs)
            ..where((rs) =>
                rs.roundId.equals(roundId) & rs.personId.equals(personId))
            ..orderBy([(rs) => OrderingTerm.asc(rs.orderIndex)]))
          .get();

  /// Get song entries with full song details for a person in a round.
  Future<List<RoundSongWithDetails>> getSongsWithDetailsForRoundPerson({
    required int roundId,
    required int personId,
  }) {
    final query = select(roundSongs).join([
      innerJoin(songs, songs.id.equalsExp(roundSongs.songId)),
      innerJoin(people, people.id.equalsExp(roundSongs.personId)),
    ]);
    query.where(roundSongs.roundId.equals(roundId) &
        roundSongs.personId.equals(personId));
    query.orderBy([OrderingTerm.asc(roundSongs.orderIndex)]);
    return query.get().then((rows) => rows
        .map((r) => RoundSongWithDetails(
              entry: r.readTable(roundSongs),
              song: r.readTable(songs),
              person: r.readTable(people),
            ))
        .toList());
  }

  /// Watch song entries with full song details for a person in a round.
  Stream<List<RoundSongWithDetails>> watchSongsWithDetailsForRoundPerson({
    required int roundId,
    required int personId,
  }) {
    final query = select(roundSongs).join([
      innerJoin(songs, songs.id.equalsExp(roundSongs.songId)),
      innerJoin(people, people.id.equalsExp(roundSongs.personId)),
    ]);
    query.where(roundSongs.roundId.equals(roundId) &
        roundSongs.personId.equals(personId));
    query.orderBy([OrderingTerm.asc(roundSongs.orderIndex)]);
    return query.watch().map((rows) => rows
        .map((r) => RoundSongWithDetails(
              entry: r.readTable(roundSongs),
              song: r.readTable(songs),
              person: r.readTable(people),
            ))
        .toList());
  }

  /// Check if a song already exists for a person in a round.
  Future<bool> songExistsForRoundPerson({
    required int roundId,
    required int personId,
    required int songId,
  }) async {
    final result = await (select(roundSongs)
          ..where((rs) =>
              rs.roundId.equals(roundId) &
              rs.personId.equals(personId) &
              rs.songId.equals(songId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Delete all data for a round (cascade helper).
  Future<void> deleteRoundData(int roundId) async {
    await (delete(roundSongs)..where((rs) => rs.roundId.equals(roundId))).go();
    await (delete(roundPeople)..where((rp) => rp.roundId.equals(roundId))).go();
  }

  /// Count songs for a round.
  Future<int> countSongsInRound(int roundId) async {
    final count = roundSongs.id.count();
    final query = selectOnly(roundSongs)
      ..addColumns([count])
      ..where(roundSongs.roundId.equals(roundId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Count people in a round.
  Future<int> countPeopleInRound(int roundId) async {
    final count = roundPeople.id.count();
    final query = selectOnly(roundPeople)
      ..addColumns([count])
      ..where(roundPeople.roundId.equals(roundId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Stream<int> watchSongsCountInRound(int roundId) {
    final count = roundSongs.id.count();
    final query = selectOnly(roundSongs)
      ..addColumns([count])
      ..where(roundSongs.roundId.equals(roundId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Stream<int> watchPeopleCountInRound(int roundId) {
    final count = roundPeople.id.count();
    final query = selectOnly(roundPeople)
      ..addColumns([count])
      ..where(roundPeople.roundId.equals(roundId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Watch tempo distribution for all songs in a round.
  Stream<Map<String, int>> watchTempoCountsInRound(int roundId) {
    return (select(roundSongs)..where((rs) => rs.roundId.equals(roundId)))
        .watch()
        .map((list) {
      final map = {'slow': 0, 'medium': 0, 'fast': 0};
      for (final s in list) {
        final t = s.tempo.toLowerCase();
        map[t] = (map[t] ?? 0) + 1;
      }
      return map;
    });
  }

  /// Automatically reorders songs for a person in classic Garba progression:
  /// Slow (2-Taali) -> Medium (3-Taali) -> Fast (Titodo / Climax).
  Future<void> sortSongsByTempo({
    required int roundId,
    required int personId,
  }) async {
    final entries = await getSongsForRoundPerson(
      roundId: roundId,
      personId: personId,
    );
    int tempoRank(String t) {
      switch (t.toLowerCase()) {
        case 'slow':
          return 0;
        case 'medium':
          return 1;
        case 'fast':
          return 2;
        default:
          return 1;
      }
    }

    entries.sort((a, b) {
      final rankDiff = tempoRank(a.tempo).compareTo(tempoRank(b.tempo));
      if (rankDiff != 0) return rankDiff;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    for (var i = 0; i < entries.length; i++) {
      await (update(roundSongs)..where((rs) => rs.id.equals(entries[i].id)))
          .write(RoundSongsCompanion(orderIndex: Value(i)));
    }
  }
}
