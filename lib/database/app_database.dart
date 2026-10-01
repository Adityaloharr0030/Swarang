import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/people_dao.dart';
import 'daos/person_songs_dao.dart';
import 'daos/songs_dao.dart';
import 'tables/people_table.dart';
import 'tables/person_songs_table.dart';
import 'tables/songs_table.dart';

part 'app_database.g.dart';

/// The main application database.
///
/// Uses Drift with SQLite for fully offline local persistence.
/// Foreign keys are enabled for referential integrity.
@DriftDatabase(
  tables: [People, Songs, PersonSongs],
  daos: [PeopleDao, SongsDao, PersonSongsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with a custom [QueryExecutor].
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add photo_paths and pdf_path columns for direct file attachments.
          await m.addColumn(songs, songs.photoPaths);
          await m.addColumn(songs, songs.pdfPath);
        }
        if (from < 3) {
          // Recreate the table to drop the NOT NULL constraint on lyrics.
          await m.alterTable(TableMigration(songs));
        }
      },
      beforeOpen: (details) async {
        // Enable foreign key constraints.
        await customStatement('PRAGMA foreign_keys = ON');

        // Create indexes for commonly searched/filtered fields.
        if (details.wasCreated) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_name ON people(name)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_gender ON people(gender)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_date_of_birth ON people(date_of_birth)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_songs_category ON songs(category)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_person_songs_person_id ON person_songs(person_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_person_songs_song_id ON person_songs(song_id)',
          );
        }
      },
    );
  }

  /// Delete all data from all tables (used during backup restore).
  Future<void> deleteAllData() async {
    await transaction(() async {
      await delete(personSongs).go();
      await delete(songs).go();
      await delete(people).go();
    });
  }

  /// Get the database file path.
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'garba_song_manager.db');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'garba_song_manager.db'));
    return NativeDatabase.createInBackground(file);
  });
}
