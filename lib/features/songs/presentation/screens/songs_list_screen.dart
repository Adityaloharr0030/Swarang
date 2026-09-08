import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/song_card.dart';
import '../../../../database/app_database.dart';
import '../providers/songs_providers.dart';
import '../../../../core/theme/app_colors.dart';

/// Screen showing all songs in the system.
class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(filteredSongsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final count = ref.watch(songsCountProvider);
            return Text(
              'Songs${count.value != null ? ' (${count.value})' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold)
            );
          },
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 60),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) {
                    ref.read(songsSearchProvider.notifier).setQuery(query);
                    ref.invalidate(filteredSongsProvider);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title or lyrics...',
                    prefixIcon: Icon(Icons.search_rounded, 
                      color: theme.colorScheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(songsSearchProvider.notifier).clear();
                              ref.invalidate(filteredSongsProvider);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
            ),
          ),
          songsAsync.when(
            data: (songs) {
              if (songs.isEmpty) {
                if (_searchController.text.isNotEmpty) {
                  return SliverFillRemaining(
                    child: const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      subtitle: 'Try a different search term.',
                    ).animate().fadeIn(duration: 400.ms),
                  );
                }
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.music_off_rounded,
                    title: 'No songs added yet',
                    subtitle: 'Add your first song to get started.',
                    actionLabel: 'Add Song',
                    onAction: () => context.push('/songs/add'),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return _SongListItem(song: song, index: index);
                    },
                    childCount: songs.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Avoid nav bar
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/songs/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Song', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.songsGradientStart,
          foregroundColor: Colors.white,
          elevation: 4,
        ).animate().scale(delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

class _SongListItem extends ConsumerWidget {
  const _SongListItem({required this.song, required this.index});
  
  final Song song;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final singerCountAsync = ref.watch(singerCountForSongProvider(song.id));
    final singerCount = singerCountAsync.value ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SongCard(
        title: song.title,
        category: song.category,
        singerCount: singerCount,
        onTap: () => context.push('/songs/${song.id}'),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: index * 50), 
      duration: 300.ms
    ).slideX(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
