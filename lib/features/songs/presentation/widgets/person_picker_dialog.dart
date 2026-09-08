import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../people/presentation/providers/people_providers.dart';

/// Dialog for selecting people to assign to a song.
class PersonPickerDialog extends ConsumerStatefulWidget {
  const PersonPickerDialog({
    super.key,
    this.excludeSongId,
  });

  final int? excludeSongId;

  @override
  ConsumerState<PersonPickerDialog> createState() =>
      _PersonPickerDialogState();
}

class _PersonPickerDialogState extends ConsumerState<PersonPickerDialog> {
  final _selectedIds = <int>{};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(allPeopleProvider);

    return AlertDialog(
      title: const Text('Select Singers'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search people...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: peopleAsync.when(
                data: (people) {
                  final filtered = _searchQuery.isEmpty
                      ? people
                      : people
                          .where((p) => p.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No people found'),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/people/add');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Person'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final person = filtered[index];
                      return CheckboxListTile(
                        title: Text(person.name),
                        subtitle: Text(person.gender),
                        value: _selectedIds.contains(person.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(person.id);
                            } else {
                              _selectedIds.remove(person.id);
                            }
                          });
                        },
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
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/people/add');
          },
          child: const Text('Create New Person'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          child: Text('Add (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
