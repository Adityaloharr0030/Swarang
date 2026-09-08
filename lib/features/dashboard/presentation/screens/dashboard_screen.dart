import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/person_card.dart';
import '../../../../core/widgets/song_card.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../../people/presentation/providers/person_songs_providers.dart';
import '../../../songs/presentation/providers/songs_providers.dart';

/// Dashboard / Home screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final peopleCount = ref.watch(peopleCountProvider);
    final songsCount = ref.watch(songsCountProvider);
    final assignmentCount = ref.watch(assignmentCountProvider);
    final recentPeople =
        ref.watch(recentPeopleProvider(AppConstants.recentItemsCount));
    final recentSongs =
        ref.watch(recentSongsProvider(AppConstants.recentItemsCount));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Stunning Gradient Header ──
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                AppConstants.appName,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              background: const _DashboardHeaderBackground(),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => context.push('/global-search'),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Icon(Icons.search_rounded, size: 22,
                      color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'People',
                        value: peopleCount.value?.toString() ?? '—',
                        icon: Icons.people_rounded,
                        gradientColors: const [
                          AppColors.peopleGradientStart,
                          AppColors.peopleGradientEnd,
                        ],
                        onTap: () => context.go('/people'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'Songs',
                        value: songsCount.value?.toString() ?? '—',
                        icon: Icons.music_note_rounded,
                        gradientColors: const [
                          AppColors.songsGradientStart,
                          AppColors.songsGradientEnd,
                        ],
                        onTap: () => context.go('/songs'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'Links',
                        value: assignmentCount.value?.toString() ?? '—',
                        icon: Icons.link_rounded,
                        gradientColors: const [
                          AppColors.assignGradientStart,
                          AppColors.assignGradientEnd,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuickActionButton(
                      icon: Icons.person_add_rounded,
                      label: 'Add Person',
                      gradient: const [AppColors.peopleGradientStart, AppColors.peopleGradientEnd],
                      onTap: () => context.push('/people/add'),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Song',
                      gradient: const [AppColors.songsGradientStart, AppColors.songsGradientEnd],
                      onTap: () => context.push('/songs/add'),
                    ),
                    const SizedBox(width: 10),
                    _QuickActionButton(
                      icon: Icons.person_search_rounded,
                      label: 'Search',
                      gradient: const [AppColors.assignGradientStart, AppColors.assignGradientEnd],
                      onTap: () => context.go('/search'),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 28),

                // Recent people
                recentPeople.when(
                  data: (people) {
                    if (people.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Recently Added People',
                          onSeeAll: () => context.go('/people'),
                        ),
                        const SizedBox(height: 4),
                        ...people.map((person) {
                          final songCountAsync =
                              ref.watch(songCountForPersonProvider(person.id));
                          return PersonCard(
                            name: person.name,
                            dateOfBirth: person.dateOfBirth,
                            gender: person.gender,
                            songCount: songCountAsync.value ?? 0,
                            onTap: () => context.push('/people/${person.id}'),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Recent songs
                recentSongs.when(
                  data: (songs) {
                    if (songs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Recently Added Songs',
                          onSeeAll: () => context.go('/songs'),
                        ),
                        const SizedBox(height: 4),
                        ...songs.map((song) {
                          final singerCountAsync =
                              ref.watch(singerCountForSongProvider(song.id));
                          return SongCard(
                            title: song.title,
                            category: song.category,
                            singerCount: singerCountAsync.value ?? 0,
                            onTap: () => context.push('/songs/${song.id}'),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with "See All" button.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (onSeeAll != null)
          TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('See All'),
          ),
      ],
    );
  }
}

/// A premium pill-shaped quick-action button with gradient icon.
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = gradient.first;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? baseColor.withValues(alpha: 0.12)
                : baseColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: baseColor.withValues(alpha: isDark ? 0.2 : 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? baseColor.withValues(alpha: 0.9)
                      : baseColor,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auto-updating dashboard header background
class _DashboardHeaderBackground extends StatefulWidget {
  const _DashboardHeaderBackground();

  @override
  State<_DashboardHeaderBackground> createState() =>
      _DashboardHeaderBackgroundState();
}

class _DashboardHeaderBackgroundState
    extends State<_DashboardHeaderBackground> {
  late String _greeting;

  @override
  void initState() {
    super.initState();
    _greeting = _getGreetingForHour();
    _updateGreeting();
  }

  String _getGreetingForHour() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good Night 🌙';      // 12 AM to 4 AM
    if (hour < 12) return 'Good Morning ☀️';   // 5 AM to 11 AM
    if (hour < 17) return 'Good Afternoon 🌤️'; // 12 PM to 4 PM
    return 'Good Evening 🌙';                  // 5 PM to 11 PM
  }

  void _updateGreeting() {
    if (!mounted) return;
    final newGreeting = _getGreetingForHour();
    if (newGreeting != _greeting) {
      setState(() {
        _greeting = newGreeting;
      });
    }
    // Check again in 1 minute
    Future.delayed(const Duration(minutes: 1), _updateGreeting);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gradientStart.withValues(alpha: isDark ? 0.25 : 0.18),
                AppColors.gradientMid.withValues(alpha: isDark ? 0.15 : 0.08),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          right: -40,
          top: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gradientStart.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          bottom: 20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.peopleGradientStart.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Greeting text
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

