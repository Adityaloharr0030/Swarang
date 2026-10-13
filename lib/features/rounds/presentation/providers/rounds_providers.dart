import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../database/app_database.dart';
import '../../../../database/daos/rounds_dao.dart';
import '../../../people/presentation/providers/people_providers.dart'
    show databaseProvider;

/// Provider for RoundsDao.
final roundsDaoProvider = Provider<RoundsDao>((ref) {
  return ref.watch(databaseProvider).roundsDao;
});

/// Watches all rounds reactively.
final allRoundsProvider = StreamProvider<List<Round>>((ref) {
  return ref.watch(roundsDaoProvider).watchAllRounds();
});

/// Watches total number of rounds.
final roundsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(roundsDaoProvider).watchAllRounds().map((rounds) => rounds.length);
});

/// Gets a single round by ID.
final roundByIdProvider =
    FutureProvider.family<Round?, int>((ref, id) async {
  return ref.watch(roundsDaoProvider).getRoundById(id);
});

/// Watches all people in a round.
final peopleForRoundProvider =
    StreamProvider.family<List<Person>, int>((ref, roundId) {
  return ref.watch(roundsDaoProvider).watchPeopleForRound(roundId);
});

/// Watches songs with details for a person in a round.
final songsForRoundPersonProvider =
    StreamProvider.family<List<RoundSongWithDetails>, ({int roundId, int personId})>(
        (ref, args) {
  return ref
      .watch(roundsDaoProvider)
      .watchSongsWithDetailsForRoundPerson(
        roundId: args.roundId,
        personId: args.personId,
      );
});

/// Watches all songs with full details for a round directly (no person needed).
final songsForRoundProvider =
    StreamProvider.family<List<RoundSongWithDetails>, int>((ref, roundId) {
  return ref.watch(roundsDaoProvider).watchSongsWithDetailsForRound(roundId);
});

/// Watches song count for a round.
final songCountForRoundProvider =
    StreamProvider.family<int, int>((ref, roundId) {
  return ref.watch(roundsDaoProvider).watchSongsCountInRound(roundId);
});

/// Watches all song usages across all rounds, grouped by songId.
final allSongRoundUsagesProvider =
    StreamProvider<Map<int, List<SongRoundUsage>>>((ref) {
  return ref.watch(roundsDaoProvider).watchAllSongRoundUsages();
});

/// Watches all rounds where a specific song is used.
final roundsForSongProvider =
    StreamProvider.family<List<SongRoundUsage>, int>((ref, songId) {
  return ref.watch(roundsDaoProvider).watchRoundsForSong(songId);
});

/// Watches people count for a round.
final peopleCountForRoundProvider =
    StreamProvider.family<int, int>((ref, roundId) {
  return ref.watch(roundsDaoProvider).watchPeopleCountInRound(roundId);
});

// ── Notifier for currently viewed round person index (gallery navigation) ──

class RoundPersonIndexNotifier extends StateNotifier<int> {
  RoundPersonIndexNotifier() : super(0);

  void setIndex(int index) => state = index;
  void next(int max) {
    if (state < max - 1) state++;
  }

  void prev() {
    if (state > 0) state--;
  }
}

final roundPersonIndexProvider =
    StateNotifierProvider.family<RoundPersonIndexNotifier, int, int>(
        (ref, roundId) {
  return RoundPersonIndexNotifier();
});

// ── CRUD helpers ───────────────────────────────────────────────────────────

/// Create a new round. Returns its ID.
Future<int> createRound(
  WidgetRef ref, {
  required String name,
  String? notes,
  DateTime? date,
}) async {
  final dao = ref.read(roundsDaoProvider);
  final id = await dao.insertRound(
    RoundsCompanion.insert(
      name: name,
      notes: Value(notes),
      date: Value(date),
    ),
  );
  ref.invalidate(allRoundsProvider);
  return id;
}

/// Update a round.
Future<void> updateRound(
  WidgetRef ref, {
  required int id,
  required String name,
  String? notes,
  DateTime? date,
  required DateTime createdAt,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.updateRound(
    RoundsCompanion(
      id: Value(id),
      name: Value(name),
      notes: Value(notes),
      date: Value(date),
      createdAt: Value(createdAt),
      updatedAt: Value(DateTime.now()),
    ),
  );
  ref.invalidate(allRoundsProvider);
  ref.invalidate(roundByIdProvider(id));
}

/// Delete a round and all its data.
Future<void> deleteRound(WidgetRef ref, int roundId) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.deleteRoundData(roundId);
  await dao.deleteRound(roundId);
  ref.invalidate(allRoundsProvider);
}

/// Add a person to a round.
Future<void> addPersonToRound(
  WidgetRef ref, {
  required int roundId,
  required int personId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.addPersonToRound(roundId: roundId, personId: personId);
  ref.invalidate(peopleForRoundProvider(roundId));
}

/// Remove a person (and their songs) from a round.
Future<void> removePersonFromRound(
  WidgetRef ref, {
  required int roundId,
  required int personId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  // Delete all songs for this person in this round first
  final songs = await dao.getSongsForRoundPerson(
      roundId: roundId, personId: personId);
  for (final s in songs) {
    await dao.removeSongFromRoundPerson(
        roundId: roundId, personId: personId, songId: s.songId);
  }
  await dao.removePersonFromRound(roundId: roundId, personId: personId);
  ref.invalidate(peopleForRoundProvider(roundId));
  ref.invalidate(songsForRoundPersonProvider(
      (roundId: roundId, personId: personId)));
}

/// Add a song to a person in a round.
Future<void> addSongToRoundPerson(
  WidgetRef ref, {
  required int roundId,
  required int personId,
  required int songId,
  String tempo = 'medium',
}) async {
  final dao = ref.read(roundsDaoProvider);
  final exists = await dao.songExistsForRoundPerson(
      roundId: roundId, personId: personId, songId: songId);
  if (!exists) {
    final current = await dao.getSongsForRoundPerson(
        roundId: roundId, personId: personId);
    await dao.addSongToRoundPerson(
      roundId: roundId,
      personId: personId,
      songId: songId,
      tempo: tempo,
      orderIndex: current.length,
    );
  }
  ref.invalidate(
      songsForRoundPersonProvider((roundId: roundId, personId: personId)));
  ref.invalidate(songCountForRoundProvider(roundId));
}

/// Remove a song from a person in a round.
Future<void> removeSongFromRoundPerson(
  WidgetRef ref, {
  required int roundId,
  required int personId,
  required int songId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.removeSongFromRoundPerson(
      roundId: roundId, personId: personId, songId: songId);
  ref.invalidate(
      songsForRoundPersonProvider((roundId: roundId, personId: personId)));
  ref.invalidate(songCountForRoundProvider(roundId));
}

/// Watches tempo counts (slow, medium, fast) for all songs in a round.
final tempoCountsForRoundProvider =
    StreamProvider.family<Map<String, int>, int>((ref, roundId) {
  return ref.watch(roundsDaoProvider).watchTempoCountsInRound(roundId);
});

/// Update tempo for a song in a round.
Future<void> updateSongTempo(
  WidgetRef ref, {
  required int roundId,
  required int personId,
  required int entryId,
  required String tempo,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.updateSongTempo(entryId: entryId, tempo: tempo);
  ref.invalidate(
      songsForRoundPersonProvider((roundId: roundId, personId: personId)));
  ref.invalidate(tempoCountsForRoundProvider(roundId));
}

/// Automatically sort a person's songs in Garba progression: Slow -> Medium -> Fast.
Future<void> autoSortSongsByTempo(
  WidgetRef ref, {
  required int roundId,
  required int personId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.sortSongsByTempo(roundId: roundId, personId: personId);
  ref.invalidate(
      songsForRoundPersonProvider((roundId: roundId, personId: personId)));
}

/// Add a song directly to a round (no person required).
Future<void> addSongToRound(
  WidgetRef ref, {
  required int roundId,
  required int songId,
  String tempo = 'medium',
}) async {
  final dao = ref.read(roundsDaoProvider);
  final exists = await dao.songExistsInRound(roundId: roundId, songId: songId);
  if (!exists) {
    final current = await dao.getSongsForRound(roundId);
    await dao.addSongToRound(
      roundId: roundId,
      songId: songId,
      tempo: tempo,
      orderIndex: current.length,
    );
  }
  ref.invalidate(songsForRoundProvider(roundId));
  ref.invalidate(songCountForRoundProvider(roundId));
  ref.invalidate(tempoCountsForRoundProvider(roundId));
  ref.invalidate(allSongRoundUsagesProvider);
  ref.invalidate(roundsForSongProvider(songId));
}

/// Remove a song directly from a round.
Future<void> removeSongFromRound(
  WidgetRef ref, {
  required int roundId,
  required int songId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.removeSongFromRound(roundId: roundId, songId: songId);
  ref.invalidate(songsForRoundProvider(roundId));
  ref.invalidate(songCountForRoundProvider(roundId));
  ref.invalidate(tempoCountsForRoundProvider(roundId));
  ref.invalidate(allSongRoundUsagesProvider);
  ref.invalidate(roundsForSongProvider(songId));
}

/// Reorder songs within a round.
Future<void> reorderSongsForRound(
  WidgetRef ref, {
  required int roundId,
  required List<int> songIds,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.reorderSongsForRound(roundId: roundId, songIds: songIds);
  ref.invalidate(songsForRoundProvider(roundId));
}

/// Update tempo for any song in a round.
Future<void> updateRoundSongTempo(
  WidgetRef ref, {
  required int roundId,
  required int entryId,
  required String tempo,
  int? personId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.updateSongTempo(entryId: entryId, tempo: tempo);
  ref.invalidate(songsForRoundProvider(roundId));
  if (personId != null) {
    ref.invalidate(
        songsForRoundPersonProvider((roundId: roundId, personId: personId)));
  }
  ref.invalidate(tempoCountsForRoundProvider(roundId));
}

/// Automatically sort all songs in a round: Slow -> Medium -> Fast.
Future<void> autoSortRoundSongsByTempo(
  WidgetRef ref, {
  required int roundId,
}) async {
  final dao = ref.read(roundsDaoProvider);
  await dao.sortSongsByTempoForRound(roundId);
  ref.invalidate(songsForRoundProvider(roundId));
  ref.invalidate(tempoCountsForRoundProvider(roundId));
}
