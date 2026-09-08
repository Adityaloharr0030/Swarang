import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/utils/age_calculator.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/songs_providers.dart';
import '../../../people/presentation/providers/person_songs_providers.dart';
import '../widgets/singer_picker_dialog.dart';
import 'lyrics_full_screen.dart';

/// Screen showing detailed information and lyrics for a song.
class SongDetailsScreen extends ConsumerWidget {
  const SongDetailsScreen({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songByIdProvider(songId));
    final singersAsync = ref.watch(peopleForSongProvider(songId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return songAsync.when(
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Song')),
            body: const Center(child: Text('Song not found')),
          );
        }

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
                    song.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.songsGradientStart.withValues(alpha: isDark ? 0.3 : 0.2),
                              AppColors.songsGradientEnd.withValues(alpha: isDark ? 0.1 : 0.05),
                              theme.colorScheme.surface,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -40,
                        bottom: 40,
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 200,
                          color: AppColors.songsGradientStart.withValues(alpha: 0.05),
                        ),
                      ),
                      if (song.category != null)
                        Positioned(
                          left: 24,
                          bottom: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.label_outline_rounded, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  song.category!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
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
                      child: const Icon(Icons.copy_rounded, size: 20),
                    ),
                    tooltip: 'Copy Lyrics',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${song.title}\n\n${song.lyrics}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lyrics copied to clipboard')),
                      );
                    },
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, size: 20),
                    ),
                    tooltip: 'Share',
                    onPressed: () => Share.share('${song.title}\n\n${song.lyrics}', subject: song.title),
                  ),
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
                    onPressed: () => context.push('/songs/${song.id}/edit'),
                  ),
                  PopupMenuButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded, size: 20),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Text('Delete Song', style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await ConfirmDialog.show(
                          context: context,
                          title: 'Delete "${song.title}"?',
                          content: 'This will also remove all singer assignments. This action cannot be undone.',
                        );
                        if (confirmed && context.mounted) {
                          await deleteSong(ref, song.id);
                          ref.invalidate(allSongsProvider);
                          if (context.mounted) context.pop();
                        }
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
                      // Lyrics Card — tap to open full-screen reader
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => LyricsFullScreen.show(
                            context,
                            title: song.title,
                            lyrics: song.lyrics,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow
                                      .withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row with 'full screen' hint
                                Row(
                                  children: [
                                    const Icon(Icons.lyrics_rounded,
                                        size: 20,
                                        color: AppColors.songsGradientStart),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lyrics',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.songsGradientStart,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.songsGradientStart
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.open_in_full_rounded,
                                              size: 13,
                                              color:
                                                  AppColors.songsGradientStart),
                                          SizedBox(width: 4),
                                          Text(
                                            'Full Screen',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AppColors.songsGradientStart,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Preview text (up to 6 lines) with bottom fade
                                ShaderMask(
                                  shaderCallback: (rect) => LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.6, 1.0],
                                  ).createShader(rect),
                                  blendMode: BlendMode.dstIn,
                                  child: Text(
                                    song.lyrics,
                                    maxLines: 7,
                                    overflow: TextOverflow.clip,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.8,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Read full lyrics button
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.songsGradientStart
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.songsGradientStart
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.menu_book_rounded,
                                            size: 16,
                                            color:
                                                AppColors.songsGradientStart),
                                        SizedBox(width: 8),
                                        Text(
                                          'Read Full Lyrics',
                                          style: TextStyle(
                                            color: AppColors.songsGradientStart,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                      if (song.notes != null && song.notes!.isNotEmpty) ...[

                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.tertiary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.tertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(song.notes!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 150.ms),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      // Singers Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.peopleGradientStart.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.people_alt_rounded, size: 20, color: AppColors.peopleGradientStart),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Singers',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.songsGradientStart,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => _showSingerPicker(context, ref),
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Singer', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Singers List
              singersAsync.when(
                data: (singers) {
                  if (singers.isEmpty) {
                    return SliverToBoxAdapter(
                      child: const EmptyState(
                        icon: Icons.mic_off_rounded,
                        title: 'No singers assigned',
                        subtitle: 'Assign singers to this song.',
                      ).animate().fadeIn(delay: 300.ms),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final singer = singers[index];
                          final age = AgeCalculator.calculateAge(singer.dateOfBirth);
                          
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
                                  color: AppColors.peopleGradientStart.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  singer.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.peopleGradientStart,
                                  ),
                                ),
                              ),
                              title: Text(
                                singer.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('Age $age • ${singer.gender}'),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                                onPressed: () async {
                                  await removePersonFromSong(
                                    ref,
                                    personId: singer.id,
                                    songId: songId,
                                  );
                                },
                              ),
                              onTap: () => context.push('/people/${singer.id}'),
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 50))).slideX(begin: 0.1, end: 0);
                        },
                        childCount: singers.length,
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
        appBar: AppBar(title: const Text('Song')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showSingerPicker(BuildContext context, WidgetRef ref) async {
    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (context) => SingerPickerDialog(
        excludeSongId: songId,
      ),
    );
    if (selectedIds != null && selectedIds.isNotEmpty) {
      for (final personId in selectedIds) {
        await assignPeopleToSong(
          ref,
          personIds: [personId],
          songId: songId,
        );
      }
    }
  }
}
