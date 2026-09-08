import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../songs/presentation/providers/songs_providers.dart';

/// Dialog for selecting songs to assign to a person.
class SongPickerDialog extends ConsumerStatefulWidget {
  const SongPickerDialog({
    super.key,
    this.excludePersonId,
  });

  final int? excludePersonId;

  @override
  ConsumerState<SongPickerDialog> createState() => _SongPickerDialogState();
}

class _SongPickerDialogState extends ConsumerState<SongPickerDialog> {
  final _selectedIds = <int>{};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(allSongsProvider);

    return AlertDialog(
      title: const Text('Select Songs'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: songsAsync.when(
                data: (songs) {
                  final filtered = _searchQuery.isEmpty
                      ? songs
                      : songs
                          .where((s) => s.title
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No songs found'),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/songs/add');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Song'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final song = filtered[index];
                      return CheckboxListTile(
                        title: Text(song.title),
                        subtitle: song.category != null
                            ? Text(song.category!)
                            : null,
                        value: _selectedIds.contains(song.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(song.id);
                            } else {
                              _selectedIds.remove(song.id);
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
            context.push('/songs/add');
          },
          child: const Text('Create New Song'),
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
