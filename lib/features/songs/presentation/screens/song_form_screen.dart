import 'package:drift/drift.dart' hide Column;
import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/song_categories.dart';
import '../../../../core/utils/validators.dart';
import '../../../../database/app_database.dart';
import '../../data/lyrics_api_service.dart';
import '../providers/songs_providers.dart';
import '../widgets/lyrics_search_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;

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
  String _scanProgress = '';

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
        _lyricsController.text = song.lyrics;
        _category = song.category;
        _notesController.text = song.notes ?? '';
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

  /// Scans an image for text using Google ML Kit.
  Future<void> _scanLyricsFromImage() async {
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
    // High quality image for better OCR on Indic/Gujarati text
    final pickedFile =
        await picker.pickImage(source: source, imageQuality: 95);
    if (pickedFile == null || !mounted) return;

    setState(() => _isFetchingLyrics = true);

    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFile(java_io.File(pickedFile.path));
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final scannedText = _cleanOcrText(recognizedText.text);

      if (mounted) {
        if (scannedText.isNotEmpty) {
          await _insertLyrics(scannedText, 'Photo Scan');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'No text found. Try a clearer photo with good lighting.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan error: $e')));
      }
    } finally {
      textRecognizer.close();
      if (mounted) setState(() => _isFetchingLyrics = false);
    }
  }

  /// Scans a PDF for text using direct text extraction (supports Gujarati/Hindi).
  Future<void> _scanLyricsFromPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || !mounted) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _isFetchingLyrics = true;
      _scanProgress = 'Extracting text from PDF...';
    });

    try {
      final bytes = await java_io.File(path).readAsBytes();
      final document = sync_pdf.PdfDocument(inputBytes: bytes);
      
      final String extractedText = sync_pdf.PdfTextExtractor(document).extractText();
      document.dispose();

      final scannedText = _cleanOcrText(extractedText);

      if (mounted) {
        if (scannedText.isNotEmpty) {
          final lines = scannedText.split('\n').length;
          await _insertLyrics(
            scannedText,
            'PDF Document',
            successMsg: '✅ PDF text extracted successfully ($lines lines)',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'No text found. The PDF might be an image instead of a text document.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF extract error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLyrics = false;
          _scanProgress = '';
        });
      }
    }
  }

  /// Cleans raw OCR output: removes lone page numbers, trims extra blank lines.
  String _cleanOcrText(String raw) {
    final lines = raw.split('\n');
    final cleaned = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // Skip lone page numbers (e.g. "1", "- 2 -", "Page 3")
      if (RegExp(r'^(-\s*)?(page\s*)?\d+\s*(-)?$', caseSensitive: false)
          .hasMatch(trimmed)) continue;
      // Skip very short noise lines (single chars, dashes)
      if (trimmed.length == 1 && !RegExp(r'[a-zA-Z\u0A80-\u0AFF\u0900-\u097F]')
          .hasMatch(trimmed)) continue;
      cleaned.add(line);
    }

    // Collapse 3+ consecutive blank lines into 2
    final result = cleaned.join('\n');
    return result
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Inserts [text] into the lyrics field.
  /// If lyrics already exist, asks the user: Append or Replace.
  Future<void> _insertLyrics(
    String text,
    String source, {
    String? successMsg,
  }) async {
    final existing = _lyricsController.text.trim();

    if (existing.isNotEmpty) {
      // Ask user: append or replace
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lyrics Already Exist'),
          content: const Text(
              'Do you want to add the scanned text to the existing lyrics, '
              'or replace them entirely?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // replace
              child: const Text('Replace'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true), // append
              child: const Text('Append'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null) return; // dismissed

      setState(() {
        _lyricsController.text =
            choice ? '$existing\n\n$text' : text;
        _lyricsSource = source;
      });
    } else {
      setState(() {
        _lyricsController.text = text;
        _lyricsSource = source;
      });
    }

    // Move cursor to end so user sees the inserted text
    _lyricsController.selection = TextSelection.collapsed(
        offset: _lyricsController.text.length);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMsg ?? '✅ Lyrics loaded from $source'),
        backgroundColor: source == 'PDF Scan'
            ? Colors.blue.shade700
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing && _existingSong != null) {
        final companion = SongsCompanion(
          id: Value(_existingSong!.id),
          title: Value(_titleController.text.trim()),
          lyrics: Value(_lyricsController.text.trim()),
          category: Value(_category),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
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
          lyrics: Value(_lyricsController.text.trim()),
          category: Value(_category),
          notes: Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
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

            // Search lyrics button (AI-powered)
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
                    onPressed: _isFetchingLyrics ? null : _scanLyricsFromImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan'),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isFetchingLyrics ? null : _scanLyricsFromPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
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
                            : _lyricsSource == 'PDF Scan'
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _lyricsSource == 'Groq AI'
                                ? Icons.auto_awesome
                                : _lyricsSource == 'PDF Scan'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.cloud_done,
                            size: 14,
                            color: _lyricsSource == 'Groq AI'
                                ? Colors.amber.shade800
                                : _lyricsSource == 'PDF Scan'
                                    ? Colors.blue.shade800
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
                                  : _lyricsSource == 'PDF Scan'
                                      ? Colors.blue.shade800
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
            
            // Loading banner while scanning — field stays mounted below
            if (_isFetchingLyrics)
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
                        _scanProgress.isNotEmpty
                            ? _scanProgress
                            : 'Processing...',
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
              validator: Validators.validateLyrics,
              maxLines: null,   // Expands to show ALL lyrics (no clipping)
              minLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Lyrics *',
                hintText:
                    'Enter song lyrics...\n\nYou can type, search with AI, scan a photo, or import from PDF.',
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
}
