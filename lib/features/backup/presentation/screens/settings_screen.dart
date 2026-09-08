import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../database/app_database.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../../people/presentation/providers/person_songs_providers.dart';
import '../../../songs/presentation/providers/songs_providers.dart';
import '../../../../core/theme/theme_provider.dart';

/// Settings screen with backup/restore, theme, and about sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final peopleCount = ref.watch(peopleCountProvider);
    final songsCount = ref.watch(songsCountProvider);
    final assignmentCount = ref.watch(assignmentCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Database section
          const _SectionHeader(title: 'Database'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Backup'),
            subtitle: const Text('Save all data to a JSON file'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Backup'),
            subtitle: const Text('Restore data from a backup file'),
            onTap: () => _importBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Database Statistics'),
            subtitle: Text(
              'People: ${peopleCount.value ?? "—"} • '
              'Songs: ${songsCount.value ?? "—"} • '
              'Assignments: ${assignmentCount.value ?? "—"}',
            ),
          ),
          const Divider(),

          // Appearance section
          const _SectionHeader(title: 'Appearance'),
          _ThemeTile(
            title: 'Light',
            themeMode: ThemeMode.light,
            currentMode: themeMode,
            ref: ref,
          ),
          _ThemeTile(
            title: 'Dark',
            themeMode: ThemeMode.dark,
            currentMode: themeMode,
            ref: ref,
          ),
          _ThemeTile(
            title: 'System',
            themeMode: ThemeMode.system,
            currentMode: themeMode,
            ref: ref,
          ),
          const Divider(),

          // About section
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppConstants.appName),
            subtitle: Text('Version ${AppConstants.appVersion}'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final peopleDao = db.peopleDao;
      final songsDao = db.songsDao;
      final personSongsDao = db.personSongsDao;

      final allPeople = await peopleDao.getAllPeople();
      final allSongs = await songsDao.getAllSongs();
      final allAssignments = await personSongsDao.getAllAssignments();

      final backupData = {
        'version': AppConstants.backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'people': allPeople
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'dateOfBirth': p.dateOfBirth.toIso8601String(),
                  'gender': p.gender,
                  'phoneNumber': p.phoneNumber,
                  'notes': p.notes,
                  'photoPath': p.photoPath,
                  'createdAt': p.createdAt.toIso8601String(),
                  'updatedAt': p.updatedAt.toIso8601String(),
                })
            .toList(),
        'songs': allSongs
            .map((s) => {
                  'id': s.id,
                  'title': s.title,
                  'lyrics': s.lyrics,
                  'category': s.category,
                  'notes': s.notes,
                  'createdAt': s.createdAt.toIso8601String(),
                  'updatedAt': s.updatedAt.toIso8601String(),
                })
            .toList(),
        'personSongs': allAssignments
            .map((ps) => {
                  'id': ps.id,
                  'personId': ps.personId,
                  'songId': ps.songId,
                  'notes': ps.notes,
                  'createdAt': ps.createdAt.toIso8601String(),
                })
            .toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'garba_backup_$timestamp${AppConstants.backupFileExtension}';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Garba Song Manager Backup',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonStr = await file.readAsString();

      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid backup file format')),
          );
        }
        return;
      }

      // Validate structure
      if (!data.containsKey('version') ||
          !data.containsKey('people') ||
          !data.containsKey('songs') ||
          !data.containsKey('personSongs')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backup file is missing required data')),
          );
        }
        return;
      }

      final peopleList = data['people'] as List;
      final songsList = data['songs'] as List;
      final assignmentsList = data['personSongs'] as List;

      if (!context.mounted) return;
      final confirmed = await ConfirmDialog.show(
        context: context,
        title: 'Restore Backup?',
        content: 'This will replace ALL current data with:\n\n'
            '• ${peopleList.length} people\n'
            '• ${songsList.length} songs\n'
            '• ${assignmentsList.length} assignments\n\n'
            'This action cannot be undone.',
        confirmLabel: 'Restore',
        isDestructive: true,
      );

      if (!confirmed) return;

      final db = ref.read(databaseProvider);

      await db.transaction(() async {
        // Clear existing data
        await db.deleteAllData();

        // Import people
        for (final p in peopleList) {
          final map = p as Map<String, dynamic>;
          await db.into(db.people).insert(
                PeopleCompanion.insert(
                  name: map['name'] as String,
                  dateOfBirth: DateTime.parse(map['dateOfBirth'] as String),
                  gender: map['gender'] as String,
                  phoneNumber: Value(map['phoneNumber'] as String?),
                  notes: Value(map['notes'] as String?),
                  photoPath: Value(map['photoPath'] as String?),
                  createdAt:
                      Value(DateTime.parse(map['createdAt'] as String)),
                  updatedAt:
                      Value(DateTime.parse(map['updatedAt'] as String)),
                ),
              );
        }

        // Import songs
        for (final s in songsList) {
          final map = s as Map<String, dynamic>;
          await db.into(db.songs).insert(
                SongsCompanion.insert(
                  title: map['title'] as String,
                  lyrics: map['lyrics'] as String,
                  category: Value(map['category'] as String?),
                  notes: Value(map['notes'] as String?),
                  createdAt:
                      Value(DateTime.parse(map['createdAt'] as String)),
                  updatedAt:
                      Value(DateTime.parse(map['updatedAt'] as String)),
                ),
              );
        }

        // Import assignments
        for (final ps in assignmentsList) {
          final map = ps as Map<String, dynamic>;
          await db.into(db.personSongs).insert(
                PersonSongsCompanion.insert(
                  personId: map['personId'] as int,
                  songId: map['songId'] as int,
                  notes: Value(map['notes'] as String?),
                  createdAt:
                      Value(DateTime.parse(map['createdAt'] as String)),
                ),
              );
        }
      });

      // Refresh all providers
      ref.invalidate(allPeopleProvider);
      ref.invalidate(allSongsProvider);
      ref.invalidate(peopleCountProvider);
      ref.invalidate(songsCountProvider);
      ref.invalidate(assignmentCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Theme selection tile using ListTile + Radio instead of deprecated RadioListTile.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.themeMode,
    required this.currentMode,
    required this.ref,
  });

  final String title;
  final ThemeMode themeMode;
  final ThemeMode currentMode;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isSelected = themeMode == currentMode;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
      },
    );
  }
}
