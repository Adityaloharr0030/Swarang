import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../people/presentation/providers/people_providers.dart';


/// Dialog to pick singers (people) to assign to a song.
class SingerPickerDialog extends ConsumerStatefulWidget {
  const SingerPickerDialog({super.key, required this.excludeSongId});

  final int excludeSongId;

  @override
  ConsumerState<SingerPickerDialog> createState() => _SingerPickerDialogState();
}

class _SingerPickerDialogState extends ConsumerState<SingerPickerDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    // For simplicity, we just show all people right now. 
    // In a full implementation, we'd exclude those already assigned.
    final peopleAsync = ref.watch(allPeopleProvider);

    return AlertDialog(
      title: const Text('Select Singers'),
      content: SizedBox(
        width: double.maxFinite,
        child: peopleAsync.when(
          data: (people) {
            if (people.isEmpty) {
              return const Text('No singers available.');
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: people.length,
              itemBuilder: (context, index) {
                final person = people[index];
                final isSelected = _selectedIds.contains(person.id);
                return CheckboxListTile(
                  title: Text(person.name),
                  value: isSelected,
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
