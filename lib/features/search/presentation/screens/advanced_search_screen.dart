import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/gender.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/person_card.dart';
import '../../../../database/app_database.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../../../songs/presentation/providers/songs_providers.dart';

/// Advanced search filters state.
class SearchFilters {
  final String? nameQuery;
  final int? minAge;
  final int? maxAge;
  final Gender? gender;
  final int? songId;

  const SearchFilters({
    this.nameQuery,
    this.minAge,
    this.maxAge,
    this.gender,
    this.songId,
  });

  bool get hasActiveFilters =>
      (nameQuery != null && nameQuery!.isNotEmpty) ||
      minAge != null ||
      maxAge != null ||
      gender != null ||
      songId != null;

  SearchFilters copyWith({
    String? nameQuery,
    int? minAge,
    int? maxAge,
    Gender? gender,
    int? songId,
    bool clearName = false,
    bool clearMinAge = false,
    bool clearMaxAge = false,
    bool clearGender = false,
    bool clearSong = false,
  }) {
    return SearchFilters(
      nameQuery: clearName ? null : (nameQuery ?? this.nameQuery),
      minAge: clearMinAge ? null : (minAge ?? this.minAge),
      maxAge: clearMaxAge ? null : (maxAge ?? this.maxAge),
      gender: clearGender ? null : (gender ?? this.gender),
      songId: clearSong ? null : (songId ?? this.songId),
    );
  }
}

/// Notifier for search filters state.
class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier() : super(const SearchFilters());

  void setNameQuery(String query) =>
      state = state.copyWith(nameQuery: query, clearName: query.isEmpty);
  void setMinAge(int? age) =>
      state = state.copyWith(minAge: age, clearMinAge: age == null);
  void setMaxAge(int? age) =>
      state = state.copyWith(maxAge: age, clearMaxAge: age == null);
  void setGender(Gender? gender) =>
      state = state.copyWith(gender: gender, clearGender: gender == null);
  void setSongId(int? songId) =>
      state = state.copyWith(songId: songId, clearSong: songId == null);
  void clear() => state = const SearchFilters();
}

final searchFiltersProvider =
    StateNotifierProvider<SearchFiltersNotifier, SearchFilters>((ref) {
  return SearchFiltersNotifier();
});

/// Performs the search query.
final searchResultsProvider = FutureProvider<List<Person>>((ref) async {
  final filters = ref.watch(searchFiltersProvider);
  final dao = ref.watch(peopleDaoProvider);

  if (!filters.hasActiveFilters) return [];

  // Convert age range to date-of-birth range.
  final now = DateTime.now();
  DateTime? minDob; // maxAge → oldest person → earliest DOB
  DateTime? maxDob; // minAge → youngest person → latest DOB

  if (filters.maxAge != null) {
    minDob = DateTime(now.year - filters.maxAge! - 1, now.month, now.day);
  }
  if (filters.minAge != null) {
    maxDob = DateTime(now.year - filters.minAge!, now.month, now.day);
  }

  return dao.advancedSearch(
    nameQuery: filters.nameQuery,
    minDateOfBirth: minDob,
    maxDateOfBirth: maxDob,
    gender: filters.gender?.name,
    songId: filters.songId,
  );
});

/// Advanced search screen with combined filters.
class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final _nameController = TextEditingController();
  RangeValues _ageRange = const RangeValues(0, 100);
  bool _ageFilterActive = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(searchFiltersProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
        actions: [
          if (filters.hasActiveFilters)
            TextButton(
              onPressed: () {
                ref.read(searchFiltersProvider.notifier).clear();
                _nameController.clear();
                setState(() {
                  _ageFilterActive = false;
                  _ageRange = const RangeValues(0, 100);
                });
              },
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Name
                  TextField(
                    controller: _nameController,
                    onChanged: (value) {
                      ref
                          .read(searchFiltersProvider.notifier)
                          .setNameQuery(value);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: Icon(Icons.person_search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gender
                  Text('Gender', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: filters.gender == null,
                        onSelected: (_) {
                          ref
                              .read(searchFiltersProvider.notifier)
                              .setGender(null);
                        },
                      ),
                      ...Gender.values.map((g) {
                        return FilterChip(
                          label: Text(g.displayName),
                          selected: filters.gender == g,
                          onSelected: (selected) {
                            ref
                                .read(searchFiltersProvider.notifier)
                                .setGender(selected ? g : null);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Age range
                  Row(
                    children: [
                      Text('Age Range', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 8),
                      Switch(
                        value: _ageFilterActive,
                        onChanged: (value) {
                          setState(() => _ageFilterActive = value);
                          if (value) {
                            ref
                                .read(searchFiltersProvider.notifier)
                                .setMinAge(_ageRange.start.toInt());
                            ref
                                .read(searchFiltersProvider.notifier)
                                .setMaxAge(_ageRange.end.toInt());
                          } else {
                            ref
                                .read(searchFiltersProvider.notifier)
                                .setMinAge(null);
                            ref
                                .read(searchFiltersProvider.notifier)
                                .setMaxAge(null);
                          }
                        },
                      ),
                      if (_ageFilterActive)
                        Text(
                          '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  if (_ageFilterActive)
                    RangeSlider(
                      values: _ageRange,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      labels: RangeLabels(
                        '${_ageRange.start.round()}',
                        '${_ageRange.end.round()}',
                      ),
                      onChanged: (values) {
                        setState(() => _ageRange = values);
                        ref
                            .read(searchFiltersProvider.notifier)
                            .setMinAge(values.start.toInt());
                        ref
                            .read(searchFiltersProvider.notifier)
                            .setMaxAge(values.end.toInt());
                      },
                    ),
                  const SizedBox(height: 12),

                  // Song filter
                  allSongsAsync.when(
                    data: (songs) {
                      if (songs.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int?>(
                        initialValue: filters.songId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Song',
                          prefixIcon: Icon(Icons.music_note),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Songs'),
                          ),
                          ...songs.map((s) {
                            return DropdownMenuItem(
                              value: s.id,
                              child: Text(s.title,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          ref
                              .read(searchFiltersProvider.notifier)
                              .setSongId(value);
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Results
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                resultsAsync.when(
                  data: (results) => Text(
                    filters.hasActiveFilters
                        ? '${results.length} ${results.length == 1 ? 'person' : 'people'} found'
                        : 'Set filters to search',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const Text('Searching...'),
                  error: (_, _) => const Text('Error'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (!filters.hasActiveFilters) {
                  return const EmptyState(
                    icon: Icons.search,
                    title: 'Search People',
                    subtitle:
                        'Use the filters above to search for singers.',
                  );
                }
                if (results.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No people match these filters',
                    subtitle: 'Try adjusting your search criteria.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final person = results[index];
                    final songCountAsync =
                        ref.watch(songCountForPersonProvider(person.id));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: PersonCard(
                        name: person.name,
                        dateOfBirth: person.dateOfBirth,
                        gender: person.gender,
                        songCount: songCountAsync.value ?? 0,
                        onTap: () => context.push('/people/${person.id}'),
                      ),
                    );
                  },
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
}
