import 'package:flutter/material.dart';

/// A group of filter chips for selecting one or more options.
class FilterChipGroup extends StatelessWidget {
  const FilterChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowMultiple = false,
  });

  final List<String> options;
  final Set<String> selected;
  final void Function(String option, bool isSelected) onSelected;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (value) => onSelected(option, value),
          showCheckmark: true,
        );
      }).toList(),
    );
  }
}
