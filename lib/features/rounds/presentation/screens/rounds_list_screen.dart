import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../database/app_database.dart';
import '../providers/rounds_providers.dart';
import '../widgets/tempo_visuals.dart';

/// Screen showing all Rounds.
class RoundsListScreen extends ConsumerWidget {
  const RoundsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(allRoundsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Rounds',
          style: TextStyle(fontWeight: FontWeight.bold),
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
            child: SizedBox(
                height: MediaQuery.of(context).padding.top + 60),
          ),

          // Info banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6F00).withValues(alpha: isDark ? 0.25 : 0.15),
                      const Color(0xFFBF360C).withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFF6F00).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6F00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.loop_rounded,
                          color: Color(0xFFFF6F00), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Rounds',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Organize songs with tempo & swipe like a gallery',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
            ),
          ),

          roundsAsync.when(
            data: (rounds) {
              if (rounds.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.view_carousel_rounded,
                    title: 'No rounds yet',
                    subtitle:
                        'Create your first round to organize songs and swipe during performances.',
                    actionLabel: 'Create Round',
                    onAction: () => context.push('/rounds/add'),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final round = rounds[index];
                      return _RoundCard(
                        round: round,
                        index: index,
                      );
                    },
                    childCount: rounds.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/rounds/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Round',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFFF6F00),
          foregroundColor: Colors.white,
          elevation: 4,
        ).animate().scale(
            delay: 200.ms,
            duration: 300.ms,
            curve: Curves.easeOutBack),
      ),
    );
  }
}

class _RoundCard extends ConsumerWidget {
  const _RoundCard({required this.round, required this.index});

  final Round round;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');

    final songCountAsync = ref.watch(songCountForRoundProvider(round.id));
    final songCount = songCountAsync.value ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/rounds/${round.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top gradient bar
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
                    ),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6F00),
                                  Color(0xFFBF360C)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.loop_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  round.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (round.date != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded,
                                          size: 12,
                                          color: theme.colorScheme
                                              .onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(round.date!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // More menu
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: theme.colorScheme.onSurfaceVariant),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    const Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18,
                                        color: theme.colorScheme.error),
                                    const SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(
                                            color:
                                                theme.colorScheme.error)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                                context.push('/rounds/${round.id}/edit');
                              } else if (value == 'delete') {
                                final confirmed = await ConfirmDialog.show(
                                  context: context,
                                  title: 'Delete "${round.name}"?',
                                  content:
                                      'All songs organized in this round will be removed.',
                                );
                                if (confirmed && context.mounted) {
                                  await deleteRound(ref, round.id);
                                }
                              }
                            },
                          ),
                        ],
                      ),

                      if (round.notes != null &&
                          round.notes!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          round.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Stats
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.music_note_rounded,
                            label: '$songCount song${songCount == 1 ? '' : 's'}',
                            color: const Color(0xFFFF6F00),
                          ),
                          const SizedBox(width: 8),
                          const _StatChip(
                            icon: Icons.view_carousel_rounded,
                            label: 'Swipe Gallery',
                            color: Colors.teal,
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                        ],
                      ),

                      // Tempo Distribution Bar
                      if (songCount > 0) ...[
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final tempoMap = ref
                                    .watch(tempoCountsForRoundProvider(round.id))
                                    .value ??
                                const {'slow': 0, 'medium': 0, 'fast': 0};
                            return TempoDistributionBar(
                              slowCount: tempoMap['slow'] ?? 0,
                              mediumCount: tempoMap['medium'] ?? 0,
                              fastCount: tempoMap['fast'] ?? 0,
                              height: 5,
                              showLabels: true,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 60), duration: 300.ms)
        .slideX(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
