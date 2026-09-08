import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/gender.dart';
import '../../../../core/utils/validators.dart';
import '../../../../database/app_database.dart';
import '../providers/people_providers.dart';

/// Form screen for adding or editing a person.
class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({super.key, this.personId});

  /// If null, we are adding a new person. Otherwise editing.
  final int? personId;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dateOfBirth;
  Gender _gender = Gender.male;
  bool _isLoading = false;
  bool _isEditing = false;
  Person? _existingPerson;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.personId != null;
    if (_isEditing) {
      _loadPerson();
    }
  }

  Future<void> _loadPerson() async {
    final person =
        await ref.read(peopleDaoProvider).getPersonById(widget.personId!);
    if (person != null && mounted) {
      setState(() {
        _existingPerson = person;
        _nameController.text = person.name;
        _dateOfBirth = person.dateOfBirth;
        _gender = Gender.fromString(person.gender);
        _phoneController.text = person.phoneNumber ?? '';
        _notesController.text = person.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dobError = Validators.validateDateOfBirth(_dateOfBirth);
    if (dobError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dobError)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing && _existingPerson != null) {
        final companion = PeopleCompanion(
          id: Value(_existingPerson!.id),
          name: Value(_nameController.text.trim()),
          dateOfBirth: Value(_dateOfBirth!),
          gender: Value(_gender.name),
          phoneNumber: Value(_phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim()),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
          createdAt: Value(_existingPerson!.createdAt),
          updatedAt: Value(DateTime.now()),
        );
        await updatePerson(ref, companion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Person updated')),
          );
          context.pop();
        }
      } else {
        final companion = PeopleCompanion(
          name: Value(_nameController.text.trim()),
          dateOfBirth: Value(_dateOfBirth!),
          gender: Value(_gender.name),
          phoneNumber: Value(_phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim()),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
        );
        final id = await createPerson(ref, companion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Person added')),
          );
          context.pushReplacement('/people/$id');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Person' : 'Add Person'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              validator: Validators.validateName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Date of Birth
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of Birth *',
                  prefixIcon: const Icon(Icons.cake),
                  suffixIcon: const Icon(Icons.calendar_today),
                  errorText: _dateOfBirth == null &&
                          _formKey.currentState?.validate() == false
                      ? 'Date of birth is required'
                      : null,
                ),
                child: Text(
                  _dateOfBirth != null
                      ? dateFormat.format(_dateOfBirth!)
                      : 'Select date of birth',
                  style: _dateOfBirth != null
                      ? null
                      : TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gender
            DropdownButtonFormField<Gender>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon: Icon(Icons.wc),
              ),
              items: Gender.values.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(g.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _gender = value);
              },
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              validator: Validators.validatePhoneNumber,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes...',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
