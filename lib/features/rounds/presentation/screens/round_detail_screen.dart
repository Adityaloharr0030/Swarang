import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/rounds_dao.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../../songs/presentation/providers/songs_providers.dart';
import '../providers/rounds_providers.dart';
import '../widgets/tempo_visuals.dart';

/// Round Detail screen — gallery-style per-person song management.
class RoundDetailScreen extends ConsumerStatefulWidget {
  const RoundDetailScreen({super.key, required this.roundId});

  final int roundId;

  @override
  ConsumerState<RoundDetailScreen> createState() => _RoundDetailScreenState();
}

class _RoundDetailScreenState extends ConsumerState<RoundDetailScreen> {
  late PageController _pageController;
  int _currentPersonIndex = 0;

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

  void _goToPage(int index) {
    setState(() => _currentPersonIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roundAsync = ref.watch(roundByIdProvider(widget.roundId));
    final peopleAsync = ref.watch(peopleForRoundProvider(widget.roundId));
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

        return peopleAsync.when(
          data: (people) {
            // Clamp page index
            if (_currentPersonIndex >= people.length && people.isNotEmpty) {
              _currentPersonIndex = people.length - 1;
            }

            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  // App bar
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    stretch: true,
                    backgroundColor: theme.colorScheme.surface,
                    actions: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, size: 18),
                        ),
                        onPressed: () =>
                            context.push('/rounds/${round.id}/edit'),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_rounded, size: 18),
                        ),
                        tooltip: 'Add Singer',
                        onPressed: () =>
                            _showAddPersonDialog(context, people),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        round.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ).animate().fadeIn(),
                      titlePadding:
                          const EdgeInsets.only(left: 16, bottom: 16),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF6F00).withValues(
                                      alpha: isDark ? 0.3 : 0.2),
                                  const Color(0xFFBF360C).withValues(
                                      alpha: isDark ? 0.1 : 0.05),
                                  theme.colorScheme.surface,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -40,
                            bottom: 20,
                            child: Icon(
                              Icons.loop_rounded,
                              size: 160,
                              color: const Color(0xFFFF6F00)
                                  .withValues(alpha: 0.06),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: people.isEmpty
                        ? _buildEmptyPeople(context)
                        : _buildGalleryContent(
                            context, people, round, isDark, theme),
                  ),
                ],
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
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyPeople(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No singers added',
            subtitle: 'Add singers to this round to assign them songs.',
            actionLabel: 'Add Singer',
            onAction: () => _showAddPersonDialog(context, []),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildGalleryContent(
    BuildContext context,
    List<Person> people,
    Round round,
    bool isDark,
    ThemeData theme,
  ) {
    return Column(
      children: [
        const SizedBox(height: 12),

        // Singer tabs (horizontal scroll)
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSelected = i == _currentPersonIndex;
              final person = people[i];
              return GestureDetector(
                onTap: () => _goToPage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF6F00)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF6F00)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : theme.colorScheme.outlineVariant,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6F00)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    person.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(duration: 300.ms),

        // Page indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(people.length, (i) {
              final isActive = i == _currentPersonIndex;
              return GestureDetector(
                onTap: () => _goToPage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFF6F00)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),

        // PageView of singers
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: PageView.builder(
            controller: _pageController,
            itemCount: people.length,
            onPageChanged: (i) => setState(() => _currentPersonIndex = i),
            itemBuilder: (context, i) {
              final person = people[i];
              return _PersonSongPage(
                roundId: round.id,
                person: person,
                allPeople: people,
                onRemovePerson: () => _confirmRemovePerson(person),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddPersonDialog(
      BuildContext context, List<Person> alreadyAdded) async {
    final allPeopleAsync = ref.read(allPeopleProvider);
    final allPeople = allPeopleAsync.value ?? [];
    final addedIds = alreadyAdded.map((p) => p.id).toSet();
    final available =
        allPeople.where((p) => !addedIds.contains(p.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('All singers are already added to this round')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPersonSheet(
        available: available,
        onAdd: (selectedPeople) async {
          for (final person in selectedPeople) {
            await addPersonToRound(
              ref,
              roundId: widget.roundId,
              personId: person.id,
            );
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _confirmRemovePerson(Person person) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Remove ${person.name}?',
      content:
          'This will also remove all their songs in this round.',
    );
    if (confirmed) {
      await removePersonFromRound(
        ref,
        roundId: widget.roundId,
        personId: person.id,
      );
      if (_currentPersonIndex > 0) {
        setState(() => _currentPersonIndex--);
      }
    }
  }
}

// ─── Per-Person Song Page ────────────────────────────────────────────────────

class _PersonSongPage extends ConsumerStatefulWidget {
  const _PersonSongPage({
    required this.roundId,
    required this.person,
    required this.allPeople,
    required this.onRemovePerson,
  });

  final int roundId;
  final Person person;
  final List<Person> allPeople;
  final VoidCallback onRemovePerson;

  @override
  ConsumerState<_PersonSongPage> createState() => _PersonSongPageState();
}

class _PersonSongPageState extends ConsumerState<_PersonSongPage> {
  String _tempoFilter = 'all'; // 'all', 'slow', 'medium', 'fast'

  @override
  Widget build(BuildContext context) {
    final args = (roundId: widget.roundId, personId: widget.person.id);
    final songsAsync = ref.watch(songsForRoundPersonProvider(args));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Person header card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      AppColors.peopleGradientStart.withValues(alpha: 0.15),
                  child: Text(
                    widget.person.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.peopleGradientStart,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.person.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        widget.person.gender,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add song button
                FilledButton.tonalIcon(
                  onPressed: () => _showSongPickerDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Song',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF6F00).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFFFF6F00),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: widget.onRemovePerson,
                  icon: Icon(Icons.person_remove_rounded,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Remove from round',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Song list & Tempo distribution
          Expanded(
            child: songsAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EmptyState(
                        icon: Icons.music_off_rounded,
                        title: 'No songs yet',
                        subtitle:
                            'Tap "Add Song" to assign songs to ${widget.person.name}',
                        actionLabel: 'Add Song',
                        onAction: () => _showSongPickerDialog(context, ref),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms);
                }

                final slowCount = entries
                    .where((e) => e.entry.tempo.toLowerCase() == 'slow')
                    .length;
                final mediumCount = entries
                    .where((e) => e.entry.tempo.toLowerCase() == 'medium')
                    .length;
                final fastCount = entries
                    .where((e) => e.entry.tempo.toLowerCase() == 'fast')
                    .length;

                // Check if songs are out of conventional Garba tempo progression (Slow -> Medium -> Fast)
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
                for (var i = 0; i < entries.length - 1; i++) {
                  if (tempoRank(entries[i].entry.tempo) >
                      tempoRank(entries[i + 1].entry.tempo)) {
                    isOutOfTempoOrder = true;
                    break;
                  }
                }

                final filteredEntries = _tempoFilter == 'all'
                    ? entries
                    : entries
                        .where((e) =>
                            e.entry.tempo.toLowerCase() == _tempoFilter)
                        .toList();

                return Column(
                  children: [
                    // Tempo flow bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
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
                          const SizedBox(height: 8),

                          // Tempo Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip(
                                  id: 'all',
                                  label: 'All (${entries.length})',
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

                          // Auto-order suggestion banner when songs are out of tempo order
                          if (isOutOfTempoOrder && entries.length > 1) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6F00)
                                    .withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFF6F00)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 14, color: Color(0xFFFF6F00)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Garba Flow: Slow ➔ Med ➔ Fast',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await autoSortSongsByTempo(
                                        ref,
                                        roundId: widget.roundId,
                                        personId: widget.person.id,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Songs ordered in Garba flow: Slow (2-Taali) ➔ Medium (3-Taali) ➔ Fast (Titodo)'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6F00),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Auto-Order',
                                        style: TextStyle(
                                          fontSize: 10,
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

                    const SizedBox(height: 10),

                    // Song List
                    Expanded(
                      child: filteredEntries.isEmpty
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
                                    final songIds = entries
                                        .map((e) => e.entry.songId)
                                        .toList();
                                    final moved = songIds.removeAt(oldIndex);
                                    songIds.insert(newIndex, moved);
                                    final dao = ref.read(roundsDaoProvider);
                                    await dao.reorderSongsForRoundPerson(
                                      roundId: widget.roundId,
                                      personId: widget.person.id,
                                      songIds: songIds,
                                    );
                                    ref.invalidate(songsForRoundPersonProvider(
                                        (roundId: widget.roundId,
                                        personId: widget.person.id)));
                                  },
                                  itemCount: filteredEntries.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredEntries[index];
                                    return _SongEntryCard(
                                      key: ValueKey(item.entry.id),
                                      item: item,
                                      index: index,
                                      roundId: widget.roundId,
                                      personId: widget.person.id,
                                      isReorderable: true,
                                    );
                                  },
                                )
                              : ListView.builder(
                                  itemCount: filteredEntries.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredEntries[index];
                                    return _SongEntryCard(
                                      key: ValueKey(item.entry.id),
                                      item: item,
                                      index: index,
                                      roundId: widget.roundId,
                                      personId: widget.person.id,
                                      isReorderable: false,
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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
              : isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04),
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

  Future<void> _showSongPickerDialog(
      BuildContext context, WidgetRef ref) async {
    // Get already-added song IDs for this person in this round
    final dao = ref.read(roundsDaoProvider);
    final existing = await dao.getSongsForRoundPerson(
        roundId: widget.roundId, personId: widget.person.id);
    final existingIds = existing.map((e) => e.songId).toSet();

    final allSongs = ref.read(allSongsProvider).value ?? [];
    final available =
        allSongs.where((s) => !existingIds.contains(s.id)).toList();

    if (!context.mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All songs are already added for this singer')),
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
          await addSongToRoundPerson(
            ref,
            roundId: widget.roundId,
            personId: widget.person.id,
            songId: song.id,
            tempo: tempo,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── Song Entry Card ─────────────────────────────────────────────────────────

class _SongEntryCard extends ConsumerWidget {
  const _SongEntryCard({
    super.key,
    required this.item,
    required this.index,
    required this.roundId,
    required this.personId,
    this.isReorderable = true,
  });

  final RoundSongWithDetails item;
  final int index;
  final int roundId;
  final int personId;
  final bool isReorderable;

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
              // Left vertical tempo color indicator bar
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
              // Subtle soft tempo wash on the card background
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
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
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
                    // Tempo Badge with Speed Meter (tappable to select tempo)
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
                          await updateSongTempo(
                            ref,
                            roundId: roundId,
                            personId: personId,
                            entryId: item.entry.id,
                            tempo: picked,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 2),
                    // Delete button
                    IconButton(
                      onPressed: () async {
                        await removeSongFromRoundPerson(
                          ref,
                          roundId: roundId,
                          personId: personId,
                          songId: item.entry.songId,
                        );
                      },
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: theme.colorScheme.error),
                      visualDensity: VisualDensity.compact,
                    ),
                    // Drag handle
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
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: index * 40), duration: 250.ms)
        .slideX(begin: 0.05, end: 0, duration: 250.ms);
  }
}

// ─── Add Person Bottom Sheet ──────────────────────────────────────────────────

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet({
    required this.available,
    required this.onAdd,
  });

  final List<Person> available;
  final Future<void> Function(List<Person>) onAdd;

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  String _query = '';
  final Set<int> _selectedIds = {};
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _query.isEmpty
        ? widget.available
        : widget.available
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    final allSelected = filtered.isNotEmpty &&
        filtered.every((p) => _selectedIds.contains(p.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
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
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Singers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedIds.length} of ${widget.available.length} selected (no limit)',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              for (final p in filtered) {
                                _selectedIds.remove(p.id);
                              }
                            } else {
                              for (final p in filtered) {
                                _selectedIds.add(p.id);
                              }
                            }
                          });
                        },
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 16,
                          color: const Color(0xFFFF6F00),
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: const TextStyle(
                            color: Color(0xFFFF6F00),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search singers...',
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
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No singers found',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final isSelected = _selectedIds.contains(p.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(p.id);
                                } else {
                                  _selectedIds.add(p.id);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF6F00)
                                        .withValues(alpha: isDark ? 0.18 : 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFF6F00)
                                          .withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected
                                        ? const Color(0xFFFF6F00)
                                        : AppColors.peopleGradientStart
                                            .withValues(alpha: 0.15),
                                    foregroundColor: isSelected
                                        ? Colors.white
                                        : AppColors.peopleGradientStart,
                                    child: Text(
                                      p.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          p.gender,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFFFF6F00)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFF6F00)
                                            : theme.colorScheme.outlineVariant,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Bottom Action Bar
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _selectedIds.isEmpty || _isAdding
                      ? null
                      : () async {
                          setState(() => _isAdding = true);
                          final selected = widget.available
                              .where((p) => _selectedIds.contains(p.id))
                              .toList();
                          await widget.onAdd(selected);
                        },
                  icon: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.group_add_rounded),
                  label: Text(
                    _selectedIds.isEmpty
                        ? 'Select Singers'
                        : 'Add ${_selectedIds.length} Singer${_selectedIds.length > 1 ? 's' : ''} to Round',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F00),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  // Gallery-style: show song cards in a grid
  int _viewMode = 0; // 0 = list, 1 = gallery

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _query.isEmpty
        ? widget.available
        : widget.available
            .where((s) =>
                s.title.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
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
                        'Pick a Song',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      // View mode toggle
                      IconButton(
                        onPressed: () =>
                            setState(() => _viewMode = 1 - _viewMode),
                        icon: Icon(
                          _viewMode == 0
                              ? Icons.grid_view_rounded
                              : Icons.list_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search songs...',
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

                  // Tempo selector
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
                                    : isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : theme.colorScheme
                                            .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? t.color
                                      : (isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.08)
                                          : theme.colorScheme.outlineVariant
                                              .withValues(alpha: 0.4)),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: t.color
                                              .withValues(alpha: 0.25),
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

            // Song list / grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : _viewMode == 0
                      ? ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
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
                            childAspectRatio: 1.3,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(song.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: song.category != null
            ? Text(song.category!,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TempoBadge(
              tempo: selectedTempo,
              compact: true,
              showSpeedMeter: true,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.add_circle_rounded,
                color: Color(0xFFFF6F00)),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC62828), Color(0xFFEF5350)],
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
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
                    color: const Color(0xFFFF6F00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Color(0xFFFF6F00), size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
