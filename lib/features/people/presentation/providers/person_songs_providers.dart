import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/app_database.dart';
import '../../../people/presentation/providers/people_providers.dart';

/// Watches songs assigned to a person.
final songsForPersonProvider =
    StreamProvider.family<List<Song>, int>((ref, personId) {
  return ref.watch(personSongsDaoProvider).watchSongsForPerson(personId);
});

/// Watches people assigned to a song.
final peopleForSongProvider =
    StreamProvider.family<List<Person>, int>((ref, songId) {
  return ref.watch(personSongsDaoProvider).watchPeopleForSong(songId);
});

/// Total assignment count.
final assignmentCountProvider = StreamProvider<int>((ref) {
  return ref.watch(personSongsDaoProvider).watchCountAssignments();
});

/// Assign songs to a person.
Future<void> assignSongsToPerson(
  WidgetRef ref, {
  required int personId,
  required List<int> songIds,
}) async {
  final dao = ref.read(personSongsDaoProvider);
  for (final songId in songIds) {
    final exists = await dao.assignmentExists(
      personId: personId,
      songId: songId,
    );
    if (!exists) {
      await dao.assignSongToPerson(personId: personId, songId: songId);
    }
  }
  // ref.invalidate(songsForPersonProvider(personId));
  // ref.invalidate(assignmentCountProvider);
}

/// Assign people to a song.
Future<void> assignPeopleToSong(
  WidgetRef ref, {
  required int songId,
  required List<int> personIds,
}) async {
  final dao = ref.read(personSongsDaoProvider);
  for (final personId in personIds) {
    final exists = await dao.assignmentExists(
      personId: personId,
      songId: songId,
    );
    if (!exists) {
      await dao.assignSongToPerson(personId: personId, songId: songId);
    }
  }
  // ref.invalidate(peopleForSongProvider(songId));
  // ref.invalidate(assignmentCountProvider);
}

/// Remove a song from a person.
Future<void> removeSongFromPerson(
  WidgetRef ref, {
  required int personId,
  required int songId,
}) async {
  final dao = ref.read(personSongsDaoProvider);
  await dao.removeSongFromPerson(personId: personId, songId: songId);
  // ref.invalidate(songsForPersonProvider(personId));
  // ref.invalidate(assignmentCountProvider);
}

/// Remove a person from a song.
Future<void> removePersonFromSong(
  WidgetRef ref, {
  required int personId,
  required int songId,
}) async {
  final dao = ref.read(personSongsDaoProvider);
  await dao.removeSongFromPerson(personId: personId, songId: songId);
  // ref.invalidate(peopleForSongProvider(songId));
  // ref.invalidate(assignmentCountProvider);
}
