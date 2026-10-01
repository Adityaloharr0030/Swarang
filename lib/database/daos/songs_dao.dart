import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/songs_table.dart';

part 'songs_dao.g.dart';

/// Data Access Object for Songs table operations.
@DriftAccessor(tables: [Songs])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  SongsDao(super.db);

  /// Insert a new song. Returns the generated ID.
  Future<int> insertSong(SongsCompanion song) {
    return into(songs).insert(song);
  }

  /// Update an existing song.
  Future<bool> updateSong(SongsCompanion song) {
    return update(songs).replace(
      Song(
        id: song.id.value,
        title: song.title.value,
        lyrics: song.lyrics.present ? song.lyrics.value : null,
        category: song.category.present ? song.category.value : null,
        notes: song.notes.present ? song.notes.value : null,
        photoPaths: song.photoPaths.present ? song.photoPaths.value : null,
        pdfPath: song.pdfPath.present ? song.pdfPath.value : null,
        createdAt: song.createdAt.value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Delete a song by ID.
  Future<int> deleteSong(int id) {
    return (delete(songs)..where((s) => s.id.equals(id))).go();
  }

  /// Get a single song by ID.
  Future<Song?> getSongById(int id) {
    return (select(songs)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Get all songs, ordered by title.
  Future<List<Song>> getAllSongs() {
    return (select(songs)..orderBy([(s) => OrderingTerm.asc(s.title)])).get();
  }

  /// Watch all songs reactively.
  Stream<List<Song>> watchAllSongs() {
    return (select(songs)..orderBy([(s) => OrderingTerm.asc(s.title)])).watch();
  }

  /// Search songs by title (case-insensitive).
  Future<List<Song>> searchByTitle(String query) {
    return (select(songs)
          ..where((s) => s.title.lower().like('%${query.toLowerCase()}%'))
          ..orderBy([(s) => OrderingTerm.asc(s.title)]))
        .get();
  }

  /// Search songs by title OR lyrics content (case-insensitive).
  Future<List<Song>> searchByTitleOrLyrics(String query) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(songs)
          ..where((s) =>
              s.title.lower().like(lowerQuery) |
              s.lyrics.lower().like(lowerQuery))
          ..orderBy([(s) => OrderingTerm.asc(s.title)]))
        .get();
  }

  /// Filter songs by category.
  Future<List<Song>> filterByCategory(String category) {
    return (select(songs)
          ..where((s) => s.category.equals(category))
          ..orderBy([(s) => OrderingTerm.asc(s.title)]))
        .get();
  }

  /// Count total number of songs.
  Future<int> countSongs() async {
    final count = songs.id.count();
    final query = selectOnly(songs)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watch total number of songs reactively.
  Stream<int> watchCountSongs() {
    final count = songs.id.count();
    final query = selectOnly(songs)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Get recently added songs.
  Future<List<Song>> getRecentSongs(int limit) {
    return (select(songs)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Watch recently added songs reactively.
  Stream<List<Song>> watchRecentSongs(int limit) {
    return (select(songs)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(limit))
        .watch();
  }
}
