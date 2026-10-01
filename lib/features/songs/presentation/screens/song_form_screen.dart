import 'package:drift/drift.dart' hide Column;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/song_categories.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/file_storage_service.dart';
import '../../../../database/app_database.dart';
import '../../data/lyrics_api_service.dart';
import '../providers/songs_providers.dart';
import '../widgets/lyrics_search_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Form screen for adding or editing a song.
class SongFormScreen extends ConsumerStatefulWidget {
  const SongFormScreen({super.key, this.songId});

  final int? songId;

  @override
  ConsumerState<SongFormScreen> createState() => _SongFormScreenState();
}

class _SongFormScreenState extends ConsumerState<SongFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _notesController = TextEditingController();

  String? _category;
  bool _isLoading = false;
  bool _isFetchingLyrics = false;
  bool _isEditing = false;
  Song? _existingSong;
  String? _lyricsSource;

  /// Attached photo paths (local copies for offline access).
  List<String> _photoPaths = [];

  /// Attached PDF path (local copy for offline access).
  String? _pdfPath;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.songId != null;
    if (_isEditing) {
      _loadSong();
    }
  }

  Future<void> _loadSong() async {
    final song =
        await ref.read(songsDaoProvider).getSongById(widget.songId!);
    if (song != null && mounted) {
      setState(() {
        _existingSong = song;
        _titleController.text = song.title;
        _lyricsController.text = song.lyrics ?? '';
        _category = song.category;
        _notesController.text = song.notes ?? '';
        _photoPaths = song.photoPaths != null && song.photoPaths!.isNotEmpty
            ? song.photoPaths!.split(',')
            : [];
        _pdfPath = song.pdfPath;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Opens the lyrics search dialog where users can search by name or lyrics.
  Future<void> _openLyricsSearch() async {
    final result = await Navigator.of(context).push<LyricsResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LyricsSearchDialog(
          initialQuery: _titleController.text.trim(),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _lyricsController.text = result.lyrics;
        _lyricsSource = result.source;
        // If the title field is empty, auto-fill with found title.
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = result.title;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lyrics loaded from ${result.source}'
                  '${result.artist != null ? ' • ${result.artist}' : ''}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Attach photos directly (no OCR) — copies to local storage for offline.
  Future<void> _attachPhotos() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();

    if (source == ImageSource.gallery) {
      // Allow picking multiple images from gallery
      final pickedFiles = await picker.pickMultiImage(imageQuality: 95);
      if (pickedFiles.isEmpty || !mounted) return;

      setState(() => _isLoading = true);
      try {
        final storage = FileStorageService.instance;
        for (final file in pickedFiles) {
          final savedPath = await storage.savePhoto(file.path);
          _photoPaths.add(savedPath);
        }
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '📷 ${pickedFiles.length} photo${pickedFiles.length > 1 ? 's' : ''} attached'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Camera: take one photo at a time
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 95);
      if (pickedFile == null || !mounted) return;

      setState(() => _isLoading = true);
      try {
        final savedPath =
            await FileStorageService.instance.savePhoto(pickedFile.path);
        setState(() => _photoPaths.add(savedPath));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📷 Photo attached'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Attach a PDF directly (no text extraction) — copies to local storage.
  Future<void> _attachPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || !mounted) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isLoading = true);
    try {
      // Delete old PDF if replacing
      if (_pdfPath != null) {
        await FileStorageService.instance.deleteFile(_pdfPath!);
      }

      final savedPath = await FileStorageService.instance.savePdf(path);
      setState(() => _pdfPath = savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📄 PDF attached'),
            backgroundColor: Colors.blue.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error attaching PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Remove a photo at [index].
  Future<void> _removePhoto(int index) async {
    final path = _photoPaths[index];
    await FileStorageService.instance.deleteFile(path);
    setState(() => _photoPaths.removeAt(index));
  }

  /// Remove the attached PDF.
  Future<void> _removePdf() async {
    if (_pdfPath != null) {
      await FileStorageService.instance.deleteFile(_pdfPath!);
      setState(() => _pdfPath = null);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // At least one of lyrics, photos, or PDF must be provided
    final hasLyrics = _lyricsController.text.trim().isNotEmpty;
    final hasPhotos = _photoPaths.isNotEmpty;
    final hasPdf = _pdfPath != null;

    if (!hasLyrics && !hasPhotos && !hasPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add lyrics, photos, or a PDF'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final photosValue = _photoPaths.isNotEmpty ? _photoPaths.join(',') : null;

      if (_isEditing && _existingSong != null) {
        final companion = SongsCompanion(
          id: Value(_existingSong!.id),
          title: Value(_titleController.text.trim()),
          lyrics: Value(_lyricsController.text.trim().isEmpty
              ? null
              : _lyricsController.text.trim()),
          category: Value(_category),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
          photoPaths: Value(photosValue),
          pdfPath: Value(_pdfPath),
          createdAt: Value(_existingSong!.createdAt),
          updatedAt: Value(DateTime.now()),
        );
        await updateSong(ref, companion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song updated')),
          );
          context.pop();
        }
      } else {
        final companion = SongsCompanion(
          title: Value(_titleController.text.trim()),
          lyrics: Value(_lyricsController.text.trim().isEmpty
              ? null
              : _lyricsController.text.trim()),
          category: Value(_category),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
          photoPaths: Value(photosValue),
          pdfPath: Value(_pdfPath),
        );
        final id = await createSong(ref, companion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song added')),
          );
          // Use pushReplacement to avoid broken back stack.
          context.pushReplacement('/songs/$id');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Song' : 'Add Song'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              validator: (v) => Validators.validateRequired(v, 'Song title'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Song Title *',
                hintText: 'Enter song title',
                prefixIcon: Icon(Icons.music_note),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Select category',
                prefixIcon: Icon(Icons.category),
              ),
              items: SongCategories.defaults.map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),

            // ── Attach Photos & PDF buttons ──
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.tonalIcon(
                    onPressed: _isFetchingLyrics ? null : _openLyricsSearch,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('Search Lyrics'),
                  ).animate().fadeIn(duration: 400.ms),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _attachPhotos,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Photos'),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _attachPdf,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('PDF'),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_lyricsSource != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _lyricsSource == 'Groq AI'
                            ? Colors.amber.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _lyricsSource == 'Groq AI'
                                ? Icons.auto_awesome
                                : Icons.cloud_done,
                            size: 14,
                            color: _lyricsSource == 'Groq AI'
                                ? Colors.amber.shade800
                                : Colors.green.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Source: $_lyricsSource',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _lyricsSource == 'Groq AI'
                                  ? Colors.amber.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_lyricsSource == 'Groq AI') ...[
                      const SizedBox(width: 8),
                      Text(
                        'AI generated — please verify',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Attached Photos Preview ──
            if (_photoPaths.isNotEmpty) ...[
              _buildSectionLabel(theme, Icons.photo_library_rounded,
                  'Attached Photos (${_photoPaths.length})', Colors.teal),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoPaths.length + 1, // +1 for "Add More" button
                  onReorder: (oldIndex, newIndex) {
                    // Don't reorder the "Add More" button
                    if (oldIndex >= _photoPaths.length ||
                        newIndex > _photoPaths.length) return;
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _photoPaths.removeAt(oldIndex);
                      _photoPaths.insert(newIndex, item);
                    });
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    // "Add More" button at the end
                    if (index == _photoPaths.length) {
                      return Container(
                        key: const ValueKey('add_more_photo'),
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.05),
                        ),
                        child: InkWell(
                          onTap: _attachPhotos,
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 32,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add More',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final path = _photoPaths[index];
                    return Container(
                      key: ValueKey(path),
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: io.File(path).existsSync()
                                ? Image.file(
                                    io.File(path),
                                    width: 100,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 100,
                                    height: 120,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                        Icons.broken_image_rounded),
                                  ),
                          ),
                          // Page number badge
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Page ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Remove button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Attached PDF Preview ──
            if (_pdfPath != null) ...[
              _buildSectionLabel(theme, Icons.picture_as_pdf_rounded,
                  'Attached PDF', Colors.red),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.red.shade200.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.red.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Document',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                          Text(
                            _pdfPath!.split('/').last.split('\\').last,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _removePdf,
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade700),
                      tooltip: 'Remove PDF',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Loading indicator
            if (_isLoading && _photoPaths.isEmpty && _pdfPath == null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Saving files...',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ),
              ),

            // Lyrics field — ALWAYS mounted so the controller value is preserved
            TextFormField(
              controller: _lyricsController,
              maxLines: null,   // Expands to show ALL lyrics (no clipping)
              minLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Lyrics (optional)',
                hintText:
                    'Enter song lyrics...\n\nYou can also attach photos or a PDF instead.',
                prefixIcon: const Icon(Icons.lyrics),
                alignLabelWithHint: true,
                enabled: !_isFetchingLyrics,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

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

  Widget _buildSectionLabel(
      ThemeData theme, IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
