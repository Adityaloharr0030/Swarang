import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../database/app_database.dart';
import '../../../../database/daos/person_songs_dao.dart';
import '../../../../database/daos/songs_dao.dart';
import '../../../people/presentation/providers/people_providers.dart'
    show databaseProvider;

/// Provider for SongsDao.
final songsDaoProvider = Provider<SongsDao>((ref) {
  return ref.watch(databaseProvider).songsDao;
});

/// Provider for PersonSongsDao (re-exported for songs feature).
final personSongsDaoForSongsProvider = Provider<PersonSongsDao>((ref) {
  return ref.watch(databaseProvider).personSongsDao;
});

/// Watches all songs reactively.
final allSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(songsDaoProvider).watchAllSongs();
});

/// Gets a single song by ID.
final songByIdProvider =
    FutureProvider.family<Song?, int>((ref, id) async {
  return ref.watch(songsDaoProvider).getSongById(id);
});

/// Gets the singer count for a specific song.
final singerCountForSongProvider =
    FutureProvider.family<int, int>((ref, songId) async {
  return ref.watch(personSongsDaoForSongsProvider).countPeopleForSong(songId);
});

/// Gets recently added songs.
final recentSongsProvider =
    StreamProvider.family<List<Song>, int>((ref, limit) {
  return ref.watch(songsDaoProvider).watchRecentSongs(limit);
});

/// Songs count.
final songsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(songsDaoProvider).watchCountSongs();
});

/// Notifier for song search state.
class SongsSearchNotifier extends StateNotifier<String> {
  SongsSearchNotifier() : super('');

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final songsSearchProvider =
    StateNotifierProvider<SongsSearchNotifier, String>((ref) {
  return SongsSearchNotifier();
});

/// Category filter state.
class SongsCategoryNotifier extends StateNotifier<String?> {
  SongsCategoryNotifier() : super(null);

  void setCategory(String? category) => state = category;
  void clear() => state = null;
}

final songsCategoryProvider =
    StateNotifierProvider<SongsCategoryNotifier, String?>((ref) {
  return SongsCategoryNotifier();
});

/// Filtered songs based on search query and category.
final filteredSongsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(songsSearchProvider);
  final category = ref.watch(songsCategoryProvider);
  final dao = ref.watch(songsDaoProvider);

  if (query.isNotEmpty) {
    return dao.searchByTitleOrLyrics(query);
  }
  if (category != null) {
    return dao.filterByCategory(category);
  }
  return dao.getAllSongs();
});

/// Creates a new song.
Future<int> createSong(WidgetRef ref, SongsCompanion song) async {
  final dao = ref.read(songsDaoProvider);
  final id = await dao.insertSong(song);
  ref.invalidate(allSongsProvider);
  return id;
}

/// Updates an existing song.
Future<void> updateSong(WidgetRef ref, SongsCompanion song) async {
  final dao = ref.read(songsDaoProvider);
  await dao.updateSong(song);
  ref.invalidate(allSongsProvider);
  ref.invalidate(songByIdProvider(song.id.value));
}

/// Deletes a song and its person assignments.
Future<void> deleteSong(WidgetRef ref, int songId) async {
  final personSongsDao = ref.read(personSongsDaoForSongsProvider);
  final songsDao = ref.read(songsDaoProvider);

  await personSongsDao.deleteAssignmentsForSong(songId);
  await songsDao.deleteSong(songId);

  ref.invalidate(allSongsProvider);
}
