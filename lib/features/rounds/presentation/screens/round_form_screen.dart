import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../database/app_database.dart';
import '../../../people/presentation/providers/people_providers.dart';
import '../providers/rounds_providers.dart';

/// Screen for creating or editing a Round.
class RoundFormScreen extends ConsumerStatefulWidget {
  const RoundFormScreen({super.key, this.roundId});

  /// If non-null, we're editing an existing round.
  final int? roundId;

  @override
  ConsumerState<RoundFormScreen> createState() => _RoundFormScreenState();
}

class _RoundFormScreenState extends ConsumerState<RoundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final Set<int> _selectedPersonIds = {};

  DateTime? _selectedDate;
  bool _isLoading = false;
  Round? _existingRound;

  bool get _isEditing => widget.roundId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final dao = ref.read(roundsDaoProvider);
    final round = await dao.getRoundById(widget.roundId!);
    if (round != null && mounted) {
      setState(() {
        _existingRound = round;
        _nameController.text = round.name;
        _notesController.text = round.notes ?? '';
        _selectedDate = round.date;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFFFF6F00),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing && _existingRound != null) {
        await updateRound(
          ref,
          id: _existingRound!.id,
          name: _nameController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          date: _selectedDate,
          createdAt: _existingRound!.createdAt,
        );
        if (mounted) context.pop();
      } else {
        final id = await createRound(
          ref,
          name: _nameController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          date: _selectedDate,
        );
        for (final personId in _selectedPersonIds) {
          await addPersonToRound(ref, roundId: id, personId: personId);
        }
        if (mounted) context.go('/rounds/$id');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');
    final allPeopleAsync = ref.watch(allPeopleProvider);
    final allPeople = allPeopleAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Round' : 'New Round',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6F00), Color(0xFFBF360C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.loop_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Round' : 'Create a Round',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assign songs to each singer with tempo',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

            const SizedBox(height: 28),

            // Name field
            _buildLabel('Round Name *', Icons.label_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                hintText: 'e.g. Night 1 – Round 2',
                icon: Icons.text_fields_rounded,
                isDark: isDark,
                theme: theme,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              textInputAction: TextInputAction.next,
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 20),

            // Date picker
            _buildLabel('Date (optional)', Icons.calendar_today_rounded),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: _selectedDate != null
                            ? const Color(0xFFFF6F00)
                            : theme.colorScheme.onSurfaceVariant,
                        size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate != null
                          ? dateFormat.format(_selectedDate!)
                          : 'Pick a date',
                      style: TextStyle(
                        color: _selectedDate != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Icon(Icons.clear_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 20),

            // Notes field
            _buildLabel('Notes (optional)', Icons.notes_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration(
                hintText: 'Any notes about this round...',
                icon: Icons.notes_rounded,
                isDark: isDark,
                theme: theme,
              ),
            ).animate().fadeIn(delay: 200.ms),

            // Select singers section (when creating)
            if (!_isEditing) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('Select Singers (optional)', Icons.groups_rounded),
                  if (allPeople.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPersonIds.length == allPeople.length) {
                            _selectedPersonIds.clear();
                          } else {
                            _selectedPersonIds.addAll(allPeople.map((p) => p.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedPersonIds.length == allPeople.length
                            ? 'Deselect All'
                            : 'Select All (${allPeople.length})',
                        style: const TextStyle(
                          color: Color(0xFFFF6F00),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (allPeople.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'No singers added in the app yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allPeople.map((person) {
                      final isSelected =
                          _selectedPersonIds.contains(person.id);
                      return FilterChip(
                        selected: isSelected,
                        showCheckmark: true,
                        checkmarkColor: Colors.white,
                        selectedColor: const Color(0xFFFF6F00),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : theme.colorScheme.surface,
                        label: Text(
                          person.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedPersonIds.add(person.id);
                            } else {
                              _selectedPersonIds.remove(person.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],

            const SizedBox(height: 36),

            // Save button
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isEditing ? Icons.save_rounded : Icons.add_circle_rounded),
              label: Text(
                _isEditing ? 'Save Changes' : 'Create Round',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F00),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ).animate().fadeIn(delay: 250.ms).scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.gradientStart,
          width: 2,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
