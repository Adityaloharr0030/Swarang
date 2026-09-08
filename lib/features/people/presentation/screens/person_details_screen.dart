import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/utils/age_calculator.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/people_providers.dart';
import '../providers/person_songs_providers.dart';
import '../widgets/song_picker_dialog.dart';

/// Screen showing detailed information about a person.
class PersonDetailsScreen extends ConsumerWidget {
  const PersonDetailsScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personByIdProvider(personId));
    final songsAsync = ref.watch(songsForPersonProvider(personId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');

    return personAsync.when(
      data: (person) {
        if (person == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Singer')),
            body: const Center(child: Text('Singer not found')),
          );
        }

        final age = AgeCalculator.calculateAge(person.dateOfBirth);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                stretch: true,
                backgroundColor: theme.colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  title: Text(
                    person.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.peopleGradientStart.withValues(alpha: isDark ? 0.3 : 0.2),
                              AppColors.peopleGradientEnd.withValues(alpha: isDark ? 0.1 : 0.05),
                              theme.colorScheme.surface,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.peopleGradientStart.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        bottom: 60,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cake_outlined, size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Age $age',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    person.gender.toLowerCase() == 'male'
                                        ? Icons.male
                                        : person.gender.toLowerCase() == 'female'
                                            ? Icons.female
                                            : Icons.person_outline_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    person.gender,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded, size: 20),
                    ),
                    tooltip: 'Edit',
                    onPressed: () => context.push('/people/${person.id}/edit'),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                    ),
                    tooltip: 'Delete',
                    onPressed: () async {
                      final confirmed = await ConfirmDialog.show(
                        context: context,
                        title: 'Delete ${person.name}?',
                        content: 'This will also remove their song assignments. This action cannot be undone.',
                      );
                      if (confirmed && context.mounted) {
                        await deletePerson(ref, person.id);
                        ref.invalidate(allPeopleProvider);
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date of Birth',
                              value: dateFormat.format(person.dateOfBirth),
                            ),
                            if (person.phoneNumber != null && person.phoneNumber!.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              _InfoRow(
                                icon: Icons.phone_rounded,
                                label: 'Phone',
                                value: person.phoneNumber!,
                              ),
                            ],
                            if (person.notes != null && person.notes!.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              _InfoRow(
                                icon: Icons.notes_rounded,
                                label: 'Notes',
                                value: person.notes!,
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Songs Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.songsGradientStart.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.music_note_rounded, size: 20, color: AppColors.songsGradientStart),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Repertoire',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.peopleGradientStart,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => _showSongPicker(context, ref),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Assign Song', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Songs List
              songsAsync.when(
                data: (songs) {
                  if (songs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: const EmptyState(
                        icon: Icons.music_off_rounded,
                        title: 'No songs assigned',
                        subtitle: 'Assign songs to this singer.',
                      ).animate().fadeIn(delay: 300.ms),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = songs[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.songsGradientStart.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.music_note_rounded, color: AppColors.songsGradientStart),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: song.category != null ? Text(song.category!) : null,
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                                onPressed: () async {
                                  await removeSongFromPerson(
                                    ref,
                                    personId: personId,
                                    songId: song.id,
                                  );
                                },
                              ),
                              onTap: () => context.push('/songs/${song.id}'),
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 50))).slideX(begin: 0.1, end: 0);
                        },
                        childCount: songs.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Singer')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showSongPicker(BuildContext context, WidgetRef ref) async {
    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (context) => SongPickerDialog(
        excludePersonId: personId,
      ),
    );
    if (selectedIds != null && selectedIds.isNotEmpty) {
      await assignSongsToPerson(
        ref,
        personId: personId,
        songIds: selectedIds,
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
