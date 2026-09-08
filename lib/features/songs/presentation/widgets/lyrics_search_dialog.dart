import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/lyrics_api_service.dart';

/// Full-screen dialog for searching lyrics by song name or partial lyrics.
///
/// Returns a [LyricsResult] when the user selects a song and its lyrics
/// are successfully fetched.
class LyricsSearchDialog extends ConsumerStatefulWidget {
  const LyricsSearchDialog({super.key, this.initialQuery});

  /// Optional initial query (e.g., pre-filled song title).
  final String? initialQuery;

  @override
  ConsumerState<LyricsSearchDialog> createState() =>
      _LyricsSearchDialogState();
}

class _LyricsSearchDialogState extends ConsumerState<LyricsSearchDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _isSearching = false;
  bool _isFetchingLyrics = false;
  List<LyricsSongMatch> _matches = [];
  LyricsResult? _directResult;
  String? _errorMessage;
  bool _hasSearched = false;
  String _selectedLanguage = 'Original';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      // Auto-search if initial query is provided.
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _matches = [];
      _directResult = null;
      _errorMessage = null;
      _hasSearched = true;
    });

    final service = ref.read(lyricsApiProvider);

    try {
      // Run LRCLIB and Groq AI search in parallel.
      // LRCLIB is usually faster (200-500ms) and returns full lyrics.
      // Groq AI covers Indian/regional songs not in LRCLIB's catalog.
      final results = await Future.wait([
        service.searchLrclibMultiple(query),
        service.searchByLyrics(query),
      ]);

      final lrclibMatches = results[0];
      final aiMatches = results[1];

      if (!mounted) return;

      if (lrclibMatches.isNotEmpty) {
        // LRCLIB wins — show instant results.
        setState(() {
          _matches = lrclibMatches;
          _isSearching = false;
        });
        return;
      }

      if (aiMatches.isNotEmpty) {
        setState(() {
          _matches = aiMatches;
          _isSearching = false;
        });
      } else {
        // Nothing found — show fallback entry.
        setState(() {
          _matches = [
            LyricsSongMatch(
              title: query,
              artist: 'Custom Search',
              snippet: 'Tap to ask AI to generate lyrics for this song...',
              source: 'Groq AI',
            )
          ];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed. Please check your connection.';
        });
      }
    }
  }

  Future<void> _selectMatch(LyricsSongMatch match) async {
    // LRCLIB match with full lyrics — return immediately for any language
    // selection that maps to Original, or always for Original.
    if (match.fullLyrics != null &&
        match.fullLyrics!.isNotEmpty &&
        (_selectedLanguage == 'Original' || match.source == 'LRCLIB' && _selectedLanguage == 'Original')) {
      Navigator.of(context).pop(LyricsResult(
        title: match.title,
        artist: match.artist.isEmpty ? null : match.artist,
        lyrics: match.fullLyrics!,
        source: match.source ?? 'LRCLIB',
      ));
      return;
    }

    // Use AI to get lyrics in the desired language/script.
    setState(() => _isFetchingLyrics = true);

    final service = ref.read(lyricsApiProvider);

    try {
      final result = await service.fetchFullLyricsFromAI(
        match.title,
        artist: match.artist,
        targetLanguage: _selectedLanguage,
      );
      if (mounted) {
        if (result != null) {
          Navigator.of(context).pop(result);
        } else {
          setState(() {
            _isFetchingLyrics = false;
            _errorMessage = 'Could not fetch lyrics for "${match.title}". '
                'Try another result or different language.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLyrics = false;
          _errorMessage = 'Failed to fetch lyrics. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Lyrics'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Enter song name or lyrics...',
                prefixIcon: const Icon(Icons.lyrics),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _matches = [];
                            _directResult = null;
                            _errorMessage = null;
                            _hasSearched = false;
                          });
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _isSearching ? null : _search,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Language Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'AI Language format: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedLanguage,
                  isDense: true,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                  icon: Icon(Icons.arrow_drop_down, size: 16, color: colorScheme.primary),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'Original', child: Text('Original')),
                    DropdownMenuItem(value: 'English (Transliteration)', child: Text('English (Transliteration)')),
                    DropdownMenuItem(value: 'Gujarati Script', child: Text('Gujarati Script')),
                    DropdownMenuItem(value: 'Hindi (Devanagari)', child: Text('Hindi (Devanagari)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                ),
              ],
            ),
          ),

          // Hint text
          if (!_hasSearched)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        size: 64,
                        color: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search by Song Name or Lyrics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Type a song title like "Nagada Sang Dhol"\n'
                        'or paste lyrics you remember\n'
                        'and we\'ll find matching songs using AI',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ).animate().fadeIn(duration: 500.ms),
                ),
              ),
            ),

          // Loading state
          if (_isSearching)
            Expanded(
              child: _buildSearchingState(theme),
            ),

          // Direct result (from LRCLIB)
          if (!_isSearching && _directResult != null)
            Expanded(
              child: _buildDirectResult(theme, colorScheme),
            ),

          // AI search results
          if (!_isSearching && _matches.isNotEmpty)
            Expanded(
              child: _buildMatchesList(theme, colorScheme),
            ),

          // Error state
          if (!_isSearching && _errorMessage != null && _matches.isEmpty && _directResult == null)
            Expanded(
              child: _buildErrorState(theme, colorScheme),
            ),

          // Loading overlay when fetching full lyrics
          if (_isFetchingLyrics) _buildFetchingOverlay(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSearchingState(ThemeData theme) {
    return Center(
      child: Shimmer.fromColors(
        baseColor: theme.colorScheme.surfaceContainerHighest,
        highlightColor: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 40),
              const SizedBox(height: 16),
              Text(
                'Searching with AI...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              for (final width in [0.9, 0.75, 0.85, 0.6, 0.8])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    height: 48,
                    width: MediaQuery.of(context).size.width * width,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectResult(ThemeData theme, ColorScheme colorScheme) {
    final result = _directResult!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Source badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Found via ${result.source}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Song info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (result.artist != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.artist!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Lyrics preview (first few lines)
                Text(
                  _previewLyrics(result.lyrics, 6),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(result),
                    icon: const Icon(Icons.check),
                    label: const Text('Use These Lyrics'),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

        const SizedBox(height: 16),

        // Option to search AI for more results
        OutlinedButton.icon(
          onPressed: () async {
            setState(() {
              _directResult = null;
              _isSearching = true;
            });
            final service = ref.read(lyricsApiProvider);
            final matches =
                await service.searchByLyrics(_controller.text.trim());
            if (mounted) {
              setState(() {
                _matches = matches;
                _isSearching = false;
                if (matches.isEmpty) {
                  _errorMessage = 'No additional matches found.';
                }
              });
            }
          },
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Search for more songs with AI'),
        ),
      ],
    );
  }

  Widget _buildMatchesList(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _matches.first.source == 'LRCLIB' ? Colors.green.shade100 : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _matches.first.source == 'LRCLIB' ? Icons.cloud_done : Icons.auto_awesome, 
                      size: 14, 
                      color: _matches.first.source == 'LRCLIB' ? Colors.green.shade800 : Colors.amber.shade800
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _matches.first.source == 'LRCLIB' ? 'Fast Results' : 'AI Results',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _matches.first.source == 'LRCLIB' ? Colors.green.shade800 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_matches.length} ${_matches.length == 1 ? 'song' : 'songs'} found',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.tertiaryContainer,
                    foregroundColor: colorScheme.onTertiaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    match.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.artist),
                      if (match.language != null)
                        Text(
                          match.language!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      if (match.snippet.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${match.snippet}"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: _isFetchingLyrics
                      ? null
                      : () => _selectMatch(match),
                  isThreeLine: true,
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: index * 80),
                    duration: 300.ms,
                  )
                  .slideX(begin: 0.05, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _search,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchingOverlay(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fetching full lyrics from AI...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedLanguage == 'Original'
                      ? 'Getting complete song text'
                      : 'Generating in $_selectedLanguage — may take a few seconds',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns first N non-empty lines of lyrics as a preview.
  String _previewLyrics(String lyrics, int maxLines) {
    final lines = lyrics
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(maxLines)
        .toList();
    if (lyrics.split('\n').where((l) => l.trim().isNotEmpty).length >
        maxLines) {
      lines.add('...');
    }
    return lines.join('\n');
  }
}
