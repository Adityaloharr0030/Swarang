import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../features/backup/presentation/screens/settings_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/people/presentation/screens/people_list_screen.dart';
import '../features/people/presentation/screens/person_details_screen.dart';
import '../features/people/presentation/screens/person_form_screen.dart';
import '../features/search/presentation/screens/advanced_search_screen.dart';
import '../features/search/presentation/screens/global_search_screen.dart';
import '../features/songs/presentation/screens/song_details_screen.dart';
import '../features/songs/presentation/screens/song_form_screen.dart';
import '../features/songs/presentation/screens/songs_list_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Application router configuration using GoRouter.
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Shell route for bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Home tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),

        // People tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/people',
              name: 'people',
              builder: (context, state) => const PeopleListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'addPerson',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const PersonFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'personDetails',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id =
                        int.parse(state.pathParameters['id']!);
                    return PersonDetailsScreen(personId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      name: 'editPerson',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id =
                            int.parse(state.pathParameters['id']!);
                        return PersonFormScreen(personId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Songs tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/songs',
              name: 'songs',
              builder: (context, state) => const SongsListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'addSong',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SongFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'songDetails',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id =
                        int.parse(state.pathParameters['id']!);
                    return SongDetailsScreen(songId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      name: 'editSong',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id =
                            int.parse(state.pathParameters['id']!);
                        return SongFormScreen(songId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Search tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              name: 'search',
              builder: (context, state) => const AdvancedSearchScreen(),
            ),
          ],
        ),

        // Settings tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Global search (full-screen, no bottom nav)
    GoRoute(
      path: '/global-search',
      name: 'globalSearch',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GlobalSearchScreen(),
    ),
  ],
);

/// Scaffold with premium floating glass bottom navigation bar.
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      index: 0,
                      currentIndex: navigationShell.currentIndex,
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      index: 1,
                      currentIndex: navigationShell.currentIndex,
                      icon: Icons.people_outline_rounded,
                      selectedIcon: Icons.people_rounded,
                      label: 'People',
                      onTap: () => _onTap(1),
                    ),
                    _NavItem(
                      index: 2,
                      currentIndex: navigationShell.currentIndex,
                      icon: Icons.music_note_outlined,
                      selectedIcon: Icons.music_note_rounded,
                      label: 'Songs',
                      onTap: () => _onTap(2),
                    ),
                    _NavItem(
                      index: 3,
                      currentIndex: navigationShell.currentIndex,
                      icon: Icons.search_rounded,
                      selectedIcon: Icons.saved_search_rounded,
                      label: 'Search',
                      onTap: () => _onTap(3),
                    ),
                    _NavItem(
                      index: 4,
                      currentIndex: navigationShell.currentIndex,
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: () => _onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// A single item in the floating bottom navigation bar.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey(isSelected),
                size: isSelected ? 26 : 22,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
