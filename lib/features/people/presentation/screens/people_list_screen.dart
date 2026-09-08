import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/person_card.dart';
import '../../../../database/app_database.dart';
import '../providers/people_providers.dart';
import '../../../../core/theme/app_colors.dart';

/// Screen showing all people in the system.
class PeopleListScreen extends ConsumerStatefulWidget {
  const PeopleListScreen({super.key});

  @override
  ConsumerState<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends ConsumerState<PeopleListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(filteredPeopleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Singers', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    ref.read(peopleSearchProvider.notifier).setQuery(query);
                    ref.invalidate(filteredPeopleProvider);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search singers...',
                    prefixIcon: Icon(Icons.search_rounded, 
                      color: theme.colorScheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(peopleSearchProvider.notifier).clear();
                              ref.invalidate(filteredPeopleProvider);
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
          peopleAsync.when(
            data: (people) {
              if (people.isEmpty) {
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
                    icon: Icons.people_alt_outlined,
                    title: 'No singers added yet',
                    subtitle: 'Add your first singer to get started.',
                    actionLabel: 'Add Singer',
                    onAction: () => context.push('/people/add'),
                  ).animate().fadeIn(duration: 400.ms),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final person = people[index];
                      return _PersonListItem(person: person, index: index);
                    },
                    childCount: people.length,
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
          onPressed: () => context.push('/people/add'),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add Singer', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.peopleGradientStart,
          foregroundColor: Colors.white,
          elevation: 4,
        ).animate().scale(delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

class _PersonListItem extends ConsumerWidget {
  const _PersonListItem({required this.person, required this.index});
  
  final Person person;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songCountAsync = ref.watch(songCountForPersonProvider(person.id));
    final songCount = songCountAsync.value ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PersonCard(
        name: person.name,
        dateOfBirth: person.dateOfBirth,
        gender: person.gender,
        songCount: songCount,
        onTap: () => context.push('/people/${person.id}'),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: index * 50), 
      duration: 300.ms
    ).slideX(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
