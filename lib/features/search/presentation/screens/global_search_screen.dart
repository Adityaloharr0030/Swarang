import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../../database/app_database.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../../songs/presentation/providers/songs_providers.dart';

/// Provider for global search query.
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for global people search results.
final globalPeopleResultsProvider = FutureProvider<List<Person>>((ref) async {
  final query = ref.watch(globalSearchQueryProvider);
  if (query.isEmpty) return [];
  return ref.watch(peopleDaoProvider).searchByName(query);
});

/// Provider for global songs search results (searches title AND lyrics).
final globalSongsResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(globalSearchQueryProvider);
  if (query.isEmpty) return [];
  return ref.watch(songsDaoProvider).searchByTitleOrLyrics(query);
});

/// Global search screen that searches across people and songs.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(globalSearchQueryProvider);
    final peopleAsync = ref.watch(globalPeopleResultsProvider);
    final songsAsync = ref.watch(globalSongsResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (value) {
            ref.read(globalSearchQueryProvider.notifier).state = value;
          },
          decoration: const InputDecoration(
            hintText: 'Search people and songs...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(globalSearchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: query.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search across people and songs',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // People results
                peopleAsync.when(
                  data: (people) {
                    if (people.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'People',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...people.map((person) {
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                foregroundColor:
                                    theme.colorScheme.onPrimaryContainer,
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(person.name),
                              subtitle: Text(person.gender),
                              onTap: () =>
                                  context.push('/people/${person.id}'),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Songs results
                songsAsync.when(
                  data: (songs) {
                    if (songs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Songs',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...songs.map((song) {
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.tertiaryContainer,
                                foregroundColor:
                                    theme.colorScheme.onTertiaryContainer,
                                child: const Icon(Icons.music_note,
                                    size: 20),
                              ),
                              title: Text(song.title),
                              subtitle: song.category != null
                                  ? Text(song.category!)
                                  : null,
                              onTap: () =>
                                  context.push('/songs/${song.id}'),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // No results
                if ((peopleAsync.value?.isEmpty ?? true) &&
                    (songsAsync.value?.isEmpty ?? true))
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'No results for "$query"',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
