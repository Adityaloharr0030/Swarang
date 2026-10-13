import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/rounds_dao.dart';
import '../../../songs/presentation/providers/songs_providers.dart';
import '../../../songs/presentation/screens/photo_gallery_screen.dart';
import '../providers/rounds_providers.dart';
import '../widgets/tempo_visuals.dart';

/// Round Detail screen — Gallery Swipe song experience for live performance.
/// Songs are added directly to the round and musicians can swipe horizontally
/// like a photo gallery to move between songs, view lyrics, and adjust tempos.
class RoundDetailScreen extends ConsumerStatefulWidget {
  const RoundDetailScreen({super.key, required this.roundId});

  final int roundId;

  @override
  ConsumerState<RoundDetailScreen> createState() => _RoundDetailScreenState();
}

class _RoundDetailScreenState extends ConsumerState<RoundDetailScreen> {
  late PageController _pageController;
  int _currentSongIndex = 0;
  bool _isGalleryMode = true; // true = Swipe Gallery, false = Playlist List
  double _lyricsFontSize = 17.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSong(int index, int totalSongs) {
    if (index < 0 || index >= totalSongs) return;
    setState(() => _currentSongIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roundAsync = ref.watch(roundByIdProvider(widget.roundId));
    final songsAsync = ref.watch(songsForRoundProvider(widget.roundId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return roundAsync.when(
      data: (round) {
        if (round == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Round')),
            body: const Center(child: Text('Round not found')),
          );
        }

        return songsAsync.when(
          data: (songs) {
            // Keep index within bounds
            if (_currentSongIndex >= songs.length && songs.isNotEmpty) {
              _currentSongIndex = songs.length - 1;
            }

            return Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      songs.isEmpty
                          ? 'No songs'
                          : '${songs.length} song${songs.length == 1 ? '' : 's'} • ${_isGalleryMode ? 'Gallery Swipe' : 'Playlist View'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                backgroundColor: theme.colorScheme.surface,
                elevation: 0,
                actions: [
                  // Toggle between Gallery Swipe & Playlist List
                  if (songs.isNotEmpty)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _isGalleryMode
                              ? const Color(0xFFFF6F00).withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isGalleryMode
                                ? const Color(0xFFFF6F00).withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          _isGalleryMode
                              ? Icons.format_list_bulleted_rounded
                              : Icons.view_carousel_rounded,
                          size: 19,
                          color: _isGalleryMode
                              ? const Color(0xFFFF6F00)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      tooltip: _isGalleryMode
                          ? 'Switch to Playlist List'
                          : 'Switch to Gallery Swipe',
                      onPressed: () {
                        setState(() => _isGalleryMode = !_isGalleryMode);
                      },
                    ),

                  // Add Song button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          size: 19, color: Colors.white),
                    ),
                    tooltip: 'Add Song to Round',
                    onPressed: () => _showAddSongSheet(context, songs),
                  ),

                  // Edit Round
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Round',
                    onPressed: () => context.push('/rounds/${round.id}/edit'),
                  ),
                ],
              ),
              body: songs.isEmpty
                  ? _buildEmptySongs(context, round)
                  : _isGalleryMode
                      ? _buildGallerySwipeView(
                          context, round, songs, isDark, theme)
                      : _buildPlaylistListView(
                          context, round, songs, isDark, theme),
              bottomNavigationBar: (songs.isNotEmpty && _isGalleryMode)
                  ? _buildGalleryBottomBar(
                      context, songs, isDark, theme)
                  : null,
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptySongs(BuildContext context, Round round) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6F00).withValues(alpha: 0.15),
                    const Color(0xFFBF360C).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.view_carousel_rounded,
                size: 64,
                color: Color(0xFFFF6F00),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No songs in this round yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs to this round to create a live setlist. Once added, you can swipe through lyrics and tempos like a photo gallery!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _showAddSongSheet(context, []),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Songs to Round',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ─── Mode A: Gallery Swipe View ───────────────────────────────────────────────

  Widget _buildGallerySwipeView(
    BuildContext context,
    Round round,
    List<RoundSongWithDetails> songs,
    bool isDark,
    ThemeData theme,
  ) {
    // Check if songs are out of Garba progression (Slow -> Medium -> Fast)
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

    bool isOutOfTempoOrder = false;
    for (var i = 0; i < songs.length - 1; i++) {
      if (tempoRank(songs[i].entry.tempo) >
          tempoRank(songs[i + 1].entry.tempo)) {
        isOutOfTempoOrder = true;
        break;
      }
    }

    return Column(
      children: [
        // Top gallery strip: Song indicator & quick song jumping pills
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swipe_rounded,
                            size: 14, color: Color(0xFFFF6F00)),
                        const SizedBox(width: 4),
                        Text(
                          'Song ${_currentSongIndex + 1} of ${songs.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6F00),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isOutOfTempoOrder && songs.length > 1)
                    InkWell(
                      onTap: () async {
                        await autoSortRoundSongsByTempo(ref,
                            roundId: widget.roundId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Ordered in Garba flow: Slow (2-Taali) ➔ Med (3-Taali) ➔ Fast (Titodo)'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6F00).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF6F00)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 12, color: Color(0xFFFF6F00)),
                            SizedBox(width: 4),
                            Text(
                              'Auto-Order Flow',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6F00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizontal thumbnail jumping pills
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: songs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final item = songs[i];
                    final isSelected = i == _currentSongIndex;
                    final cfg = GarbaTempoConfig.from(item.entry.tempo);
                    return GestureDetector(
                      onTap: () => _goToSong(i, songs.length),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cfg.color.withValues(alpha: isDark ? 0.25 : 0.18)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : theme.colorScheme.surface),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? cfg.color
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4)),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: cfg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '#${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : cfg.color)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: Text(
                                item.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : theme.colorScheme.onSurface)
                                      : theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Swipable PageView for Songs (Gallery Swipe Experience)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: songs.length,
            onPageChanged: (i) => setState(() => _currentSongIndex = i),
            itemBuilder: (context, i) {
              final item = songs[i];
              return _GallerySongSlide(
                item: item,
                index: i,
                totalCount: songs.length,
                roundId: widget.roundId,
                lyricsFontSize: _lyricsFontSize,
                onFontSizeChange: (newSize) {
                  setState(() => _lyricsFontSize = newSize);
                },
                onRemove: () => _confirmRemoveSong(item),
                onTempoChange: (newTempo) async {
                  await updateRoundSongTempo(
                    ref,
                    roundId: widget.roundId,
                    entryId: item.entry.id,
                    tempo: newTempo,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Gallery Bottom Navigation Bar ──────────────────────────────────────────

  Widget _buildGalleryBottomBar(
    BuildContext context,
    List<RoundSongWithDetails> songs,
    bool isDark,
    ThemeData theme,
  ) {
    final hasPrev = _currentSongIndex > 0;
    final hasNext = _currentSongIndex < songs.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161D) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous Song button
          OutlinedButton.icon(
            onPressed:
                hasPrev ? () => _goToSong(_currentSongIndex - 1, songs.length) : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Prev'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const Spacer(),

          // Indicator Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              songs.length > 9 ? 9 : songs.length,
              (dotIdx) {
                // If many songs, show window around current
                final bool isActive;
                if (songs.length <= 9) {
                  isActive = dotIdx == _currentSongIndex;
                } else {
                  final activeSlot =
                      ((_currentSongIndex / (songs.length - 1)) * 8).round();
                  isActive = dotIdx == activeSlot;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFF6F00)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Next Song button
          FilledButton.icon(
            onPressed:
                hasNext ? () => _goToSong(_currentSongIndex + 1, songs.length) : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Next'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mode B: Playlist / List View ─────────────────────────────────────────────

  Widget _buildPlaylistListView(
    BuildContext context,
    Round round,
    List<RoundSongWithDetails> songs,
    bool isDark,
    ThemeData theme,
  ) {
    return _PlaylistView(
      roundId: widget.roundId,
      songs: songs,
      onConfirmRemove: _confirmRemoveSong,
    );
  }

  // ─── Dialogs and Sheets ───────────────────────────────────────────────────────

  Future<void> _showAddSongSheet(
      BuildContext context, List<RoundSongWithDetails> existing) async {
    final existingSongIds = existing.map((e) => e.song.id).toSet();
    final allSongs = ref.read(allSongsProvider).value ?? [];
    final available =
        allSongs.where((s) => !existingSongIds.contains(s.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All songs in your library are already in this round!'),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SongPickerSheet(
        available: available,
        onAdd: (song, tempo) async {
          await addSongToRound(
            ref,
            roundId: widget.roundId,
            songId: song.id,
            tempo: tempo,
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Added "${song.title}" (${GarbaTempoConfig.from(tempo).label}) to round'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmRemoveSong(RoundSongWithDetails item) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Remove "${item.song.title}"?',
      content: 'This song will be removed from this round.',
    );
    if (confirmed) {
      await removeSongFromRound(
        ref,
        roundId: widget.roundId,
        songId: item.song.id,
      );
    }
  }
}

// ─── Gallery Song Slide (Full Card in Swipe PageView) ─────────────────────────

class _GallerySongSlide extends StatelessWidget {
  const _GallerySongSlide({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.roundId,
    required this.lyricsFontSize,
    required this.onFontSizeChange,
    required this.onRemove,
    required this.onTempoChange,
  });

  final RoundSongWithDetails item;
  final int index;
  final int totalCount;
  final int roundId;
  final double lyricsFontSize;
  final ValueChanged<double> onFontSizeChange;
  final VoidCallback onRemove;
  final ValueChanged<String> onTempoChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cfg = GarbaTempoConfig.from(item.entry.tempo);

    final photoList = item.song.photoPaths != null &&
            item.song.photoPaths!.trim().isNotEmpty
        ? item.song.photoPaths!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final hasLyrics =
        item.song.lyrics != null && item.song.lyrics!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cfg.cardBorderColor(isDark),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: cfg.color.withValues(alpha: isDark ? 0.14 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top tempo header strip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cfg.color.withValues(alpha: isDark ? 0.25 : 0.15),
                      cfg.color.withValues(alpha: isDark ? 0.08 : 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: cfg.color.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Order Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cfg.color,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: cfg.color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Category tag if available
                    if (item.song.category != null &&
                        item.song.category!.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.song.category!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Interactive Tempo Badge with Speed Meter
                    TempoBadge(
                      tempo: item.entry.tempo,
                      compact: false,
                      showSpeedMeter: true,
                      onTap: () async {
                        final picked = await TempoSelectorSheet.show(
                          context,
                          currentTempo: item.entry.tempo,
                          title: 'Change Tempo • ${item.song.title}',
                        );
                        if (picked != null && picked != item.entry.tempo) {
                          onTempoChange(picked);
                        }
                      },
                    ),

                    const SizedBox(width: 4),

                    // Remove from Round button
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          size: 20, color: theme.colorScheme.error),
                      tooltip: 'Remove from Round',
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ),

              // Title section
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.song.title,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (item.song.notes != null &&
                        item.song.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.song.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Controls row: Photo Attachment Button & Font size controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (photoList.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.photo_library_rounded,
                            size: 15, color: Colors.white),
                        label: Text(
                          '${photoList.length} Sheet Photo${photoList.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.teal.shade700,
                        onPressed: () {
                          PhotoGalleryScreen.show(
                            context,
                            photoPaths: photoList,
                            title: item.song.title,
                          );
                        },
                      ),
                    const Spacer(),

                    // Font size adjuster
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (lyricsFontSize > 13) {
                              onFontSizeChange(lyricsFontSize - 2);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.text_decrease_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${lyricsFontSize.toInt()} pt',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (lyricsFontSize < 28) {
                              onFontSizeChange(lyricsFontSize + 2);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.text_increase_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              const Divider(height: 1, indent: 18, endIndent: 18),

              // Scrollable Lyrics View
              Expanded(
                child: hasLyrics
                    ? Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                          child: SelectableText(
                            item.song.lyrics!,
                            style: TextStyle(
                              fontSize: lyricsFontSize,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lyrics_rounded,
                                size: 42,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No lyrics entered for this song',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/songs/${item.song.id}/edit'),
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Add Lyrics'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // Bottom card footer: View full song details
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      cfg.garbaType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cfg.color,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/songs/${item.song.id}'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Song Details',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mode B: Playlist View (Reorderable List) ──────────────────────────────────

class _PlaylistView extends ConsumerStatefulWidget {
  const _PlaylistView({
    required this.roundId,
    required this.songs,
    required this.onConfirmRemove,
  });

  final int roundId;
  final List<RoundSongWithDetails> songs;
  final ValueChanged<RoundSongWithDetails> onConfirmRemove;

  @override
  ConsumerState<_PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends ConsumerState<_PlaylistView> {
  String _tempoFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final slowCount = widget.songs
        .where((e) => e.entry.tempo.toLowerCase() == 'slow')
        .length;
    final mediumCount = widget.songs
        .where((e) => e.entry.tempo.toLowerCase() == 'medium')
        .length;
    final fastCount = widget.songs
        .where((e) => e.entry.tempo.toLowerCase() == 'fast')
        .length;

    // Check if songs are out of tempo progression
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

    bool isOutOfTempoOrder = false;
    for (var i = 0; i < widget.songs.length - 1; i++) {
      if (tempoRank(widget.songs[i].entry.tempo) >
          tempoRank(widget.songs[i + 1].entry.tempo)) {
        isOutOfTempoOrder = true;
        break;
      }
    }

    final filtered = _tempoFilter == 'all'
        ? widget.songs
        : widget.songs
            .where((e) => e.entry.tempo.toLowerCase() == _tempoFilter)
            .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Flow and filters container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TempoDistributionBar(
                  slowCount: slowCount,
                  mediumCount: mediumCount,
                  fastCount: fastCount,
                  height: 6,
                  showLabels: true,
                ),
                const SizedBox(height: 10),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        id: 'all',
                        label: 'All (${widget.songs.length})',
                        color: theme.colorScheme.primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _filterChip(
                        id: 'slow',
                        label: '🌊 Slow ($slowCount)',
                        color: GarbaTempoConfig.slow.color,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _filterChip(
                        id: 'medium',
                        label: '⚡ Medium ($mediumCount)',
                        color: GarbaTempoConfig.medium.color,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _filterChip(
                        id: 'fast',
                        label: '🔥 Fast ($fastCount)',
                        color: GarbaTempoConfig.fast.color,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // Auto-order suggestion banner
                if (isOutOfTempoOrder && widget.songs.length > 1) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F00)
                          .withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            const Color(0xFFFF6F00).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: Color(0xFFFF6F00)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Garba Progression: Slow ➔ Med ➔ Fast',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await autoSortRoundSongsByTempo(ref,
                                roundId: widget.roundId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Songs ordered: Slow (2-Taali) ➔ Medium (3-Taali) ➔ Fast (Titodo)'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6F00),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Auto-Order',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Songs List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No ${GarbaTempoConfig.from(_tempoFilter).label} songs',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _tempoFilter == 'all'
                    ? ReorderableListView.builder(
                        onReorderItem: (oldIndex, newIndex) async {
                          final songIds =
                              widget.songs.map((e) => e.song.id).toList();
                          final moved = songIds.removeAt(oldIndex);
                          songIds.insert(newIndex, moved);
                          await reorderSongsForRound(
                            ref,
                            roundId: widget.roundId,
                            songIds: songIds,
                          );
                        },
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _SongEntryCard(
                            key: ValueKey(item.entry.id),
                            item: item,
                            index: index,
                            roundId: widget.roundId,
                            isReorderable: true,
                            onRemove: () => widget.onConfirmRemove(item),
                          );
                        },
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _SongEntryCard(
                            key: ValueKey(item.entry.id),
                            item: item,
                            index: index,
                            roundId: widget.roundId,
                            isReorderable: false,
                            onRemove: () => widget.onConfirmRemove(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String id,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _tempoFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _tempoFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Song Entry Card (used in Playlist Mode) ──────────────────────────────────

class _SongEntryCard extends ConsumerWidget {
  const _SongEntryCard({
    super.key,
    required this.item,
    required this.index,
    required this.roundId,
    required this.isReorderable,
    required this.onRemove,
  });

  final RoundSongWithDetails item;
  final int index;
  final int roundId;
  final bool isReorderable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cfg = GarbaTempoConfig.from(item.entry.tempo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cfg.cardBorderColor(isDark),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: cfg.color.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: cfg.gradient,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: cfg.subtleBgColor(isDark),
                ),
              ),
              ListTile(
                onTap: () => context.push('/songs/${item.song.id}'),
                contentPadding: const EdgeInsets.only(
                    left: 14, right: 10, top: 3, bottom: 3),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cfg.color.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cfg.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  item.song.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    if (item.song.category != null &&
                        item.song.category!.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          item.song.category!,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('•',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5))),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      cfg.garbaType,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cfg.color,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TempoBadge(
                      tempo: item.entry.tempo,
                      compact: true,
                      showSpeedMeter: true,
                      onTap: () async {
                        final picked = await TempoSelectorSheet.show(
                          context,
                          currentTempo: item.entry.tempo,
                          title: 'Change Tempo • ${item.song.title}',
                        );
                        if (picked != null && picked != item.entry.tempo) {
                          await updateRoundSongTempo(
                            ref,
                            roundId: roundId,
                            entryId: item.entry.id,
                            tempo: picked,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: onRemove,
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: theme.colorScheme.error),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (isReorderable)
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Song Picker Bottom Sheet ─────────────────────────────────────────────────

class _SongPickerSheet extends StatefulWidget {
  const _SongPickerSheet({
    required this.available,
    required this.onAdd,
  });

  final List<Song> available;
  final Future<void> Function(Song song, String tempo) onAdd;

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  String _query = '';
  String _selectedTempo = 'medium';
  int _viewMode = 0; // 0 = list, 1 = grid

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _query.isEmpty
        ? widget.available
        : widget.available
            .where((s) =>
                s.title.toLowerCase().contains(_query.toLowerCase()) ||
                (s.category != null &&
                    s.category!.toLowerCase().contains(_query.toLowerCase())))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Add Song to Round',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            setState(() => _viewMode = 1 - _viewMode),
                        icon: Icon(
                          _viewMode == 0
                              ? Icons.grid_view_rounded
                              : Icons.list_rounded,
                          color: const Color(0xFFFF6F00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search input
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by song name or category...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tempo Selector for the song being added
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assign Tempo (ગતિ)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        GarbaTempoConfig.from(_selectedTempo).garbaType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GarbaTempoConfig.from(_selectedTempo).color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: GarbaTempoConfig.all.map((t) {
                      final isSelected = _selectedTempo == t.value;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedTempo = t.value),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? t.color.withValues(
                                        alpha: isDark ? 0.22 : 0.12)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : theme.colorScheme
                                            .surfaceContainerHighest),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? t.color
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : theme.colorScheme.outlineVariant
                                              .withValues(alpha: 0.4)),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              t.color.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        t.icon,
                                        size: 16,
                                        color: isSelected
                                            ? t.color
                                            : theme.colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        t.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? t.color
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.garbaType,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? t.color
                                          : theme.colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TempoSpeedMeter(
                                    tempo: t.value,
                                    maxHeight: 12,
                                    barWidth: 3,
                                    spacing: 2,
                                    colorOverride: isSelected
                                        ? t.color
                                        : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Available Songs List/Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No songs found matching "$_query"',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : _viewMode == 0
                      ? ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return _SongPickerListItem(
                              song: s,
                              selectedTempo: _selectedTempo,
                              onTap: () => widget.onAdd(s, _selectedTempo),
                            );
                          },
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return _SongPickerGridItem(
                              song: s,
                              selectedTempo: _selectedTempo,
                              onTap: () => widget.onAdd(s, _selectedTempo),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongPickerListItem extends StatelessWidget {
  const _SongPickerListItem({
    required this.song,
    required this.selectedTempo,
    required this.onTap,
  });

  final Song song;
  final String selectedTempo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = GarbaTempoConfig.from(selectedTempo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: song.category != null
            ? Text(
                song.category!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TempoBadge(
              tempo: selectedTempo,
              compact: true,
              showSpeedMeter: true,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: cfg.color, size: 18),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}

class _SongPickerGridItem extends StatelessWidget {
  const _SongPickerGridItem({
    required this.song,
    required this.selectedTempo,
    required this.onTap,
  });

  final Song song;
  final String selectedTempo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cfg = GarbaTempoConfig.from(selectedTempo);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 14),
                ),
                const Spacer(),
                TempoBadge(
                  tempo: selectedTempo,
                  compact: true,
                  showSpeedMeter: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (song.category != null) ...[
              const SizedBox(height: 4),
              Text(
                song.category!,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_rounded, color: cfg.color, size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
