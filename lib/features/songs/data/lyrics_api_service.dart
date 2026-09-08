import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result from a lyrics search, containing metadata and the lyrics text.
class LyricsResult {
  final String title;
  final String? artist;
  final String lyrics;
  final String source;

  const LyricsResult({
    required this.title,
    this.artist,
    required this.lyrics,
    required this.source,
  });
}

/// A candidate song returned from an AI lyrics search.
class LyricsSongMatch {
  final String title;
  final String artist;
  final String? language;
  final String snippet;
  final String? fullLyrics;
  final String? source;

  const LyricsSongMatch({
    required this.title,
    required this.artist,
    this.language,
    required this.snippet,
    this.fullLyrics,
    this.source,
  });
}

/// Service to fetch song lyrics using LRCLIB (free) and Groq AI (fallback).
///
/// Strategy:
///   1. LRCLIB — large western catalog, free, no key, very fast.
///   2. Groq AI — uses Llama 3.3 70B for song search + lyrics generation.
///      - Song identification uses `llama-3.3-70b-versatile` (structured JSON).
///      - Lyrics generation uses `llama-3.1-70b-versatile` (no thinking overhead).
///
/// Performance improvements over previous version:
///   - LRCLIB and Groq AI search run in **parallel**.
///   - Removed the redundant LRCLIB call inside `fetchFullLyricsFromAI`.
///   - Switched from `qwen3.6-27b` (slow thinking model) to `llama-3.3-70b`
///     (faster, no `<think>` token waste, full lyrics without truncation).
///   - Increased lyrics token budget and tightened prompts for full output.
class LyricsApiService {
  final http.Client _client;

  static const String _groqApiKey =
      'YOUR_GROQ_API_KEY_HERE'; // Replace with your actual Groq API key
  static const String _groqBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Fast, instruction-following model for song identification (structured JSON).
  static const String _searchModel = 'llama-3.3-70b-versatile';

  /// Fast lyrics generation model — no thinking overhead, handles Indic scripts.
  static const String _lyricsModel = 'llama-3.3-70b-versatile';

  LyricsApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches lyrics for [songTitle]. Tries LRCLIB and Groq AI in parallel.
  Future<LyricsResult?> fetchLyrics(String songTitle, {String? artist}) async {
    if (songTitle.trim().isEmpty) return null;

    // Run LRCLIB and Groq AI in parallel — return whichever finishes first
    // with a valid result.
    try {
      final results = await Future.any([
        _searchLrclib(songTitle).then((r) => r),
        fetchFullLyricsFromAI(songTitle, artist: artist ?? ''),
      ]);
      return results;
    } catch (_) {}

    return null;
  }

  /// Uses Groq AI to identify songs from a partial lyrics snippet or title.
  /// Returns a list of candidate songs (up to 5).
  Future<List<LyricsSongMatch>> searchByLyrics(String lyricsSnippet) async {
    if (lyricsSnippet.trim().isEmpty) return [];

    try {
      final response = await _client
          .post(
            Uri.parse(_groqBaseUrl),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': _searchModel,
              'messages': [
                {
                  'role': 'system',
                  'content': '''You are a music expert specializing in Indian music — Bollywood, Garba, Gujarati folk, Hindi, Bhajan, Dandiya, and regional songs.
You also know English, Punjabi, Tamil, Telugu, and world music.

Given partial lyrics or a song name, return a JSON array of up to 5 matching songs.
Each object MUST have: "title", "artist", "language", "snippet" (one recognizable lyric line from that song).

CRITICAL: Return ONLY the raw JSON array. No markdown, no code blocks, no explanation.
Example: [{"title":"Nagada Sang Dhol","artist":"Shreya Ghoshal","language":"Hindi","snippet":"Nagada sang dhol baaje, haath mein talwar"}]

If no match is found, return: []''',
                },
                {
                  'role': 'user',
                  'content': 'Identify songs matching: "$lyricsSnippet"',
                }
              ],
              'temperature': 0.2,
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final content =
          data['choices']?[0]?['message']?['content'] as String? ?? '';

      final cleaned = _extractJsonArray(content);
      if (cleaned.isEmpty) return [];

      final List<dynamic> songs = json.decode(cleaned);
      return songs.map((s) {
        return LyricsSongMatch(
          title: (s['title'] as String?) ?? '',
          artist: (s['artist'] as String?) ?? '',
          language: s['language'] as String?,
          snippet: (s['snippet'] as String?) ?? '',
          source: 'Groq AI',
        );
      }).where((m) => m.title.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches full lyrics from Groq AI for a confirmed song title.
  ///
  /// Supports [targetLanguage]: 'Original', 'English (Transliteration)',
  /// 'Gujarati Script', 'Hindi (Devanagari)'.
  ///
  /// Note: Does NOT retry LRCLIB — callers that need LRCLIB should call
  /// [searchLrclibMultiple] separately (already done in the dialog).
  Future<LyricsResult?> fetchFullLyricsFromAI(
    String title, {
    String artist = '',
    String targetLanguage = 'Original',
  }) async {
    final artistHint = artist.isNotEmpty ? ' by $artist' : '';

    final scriptInstruction = switch (targetLanguage) {
      'English (Transliteration)' =>
        'Write lyrics using English alphabet only (transliteration). '
            'DO NOT translate meaning — only change the script. '
            'Example: "Nagada sang dhol baaje" NOT "Drums play with kettledrum".',
      'Gujarati Script' =>
        'Write lyrics in Gujarati script (ગુજરાતી). '
            'DO NOT translate — only transcribe/transliterate into Gujarati letters.',
      'Hindi (Devanagari)' =>
        'Write lyrics in Hindi Devanagari script (हिंदी). '
            'DO NOT translate — only transcribe into Devanagari.',
      _ => 'Write in the song\'s original language and script.',
    };

    try {
      final response = await _client
          .post(
            Uri.parse(_groqBaseUrl),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': _lyricsModel,
              'messages': [
                {
                  'role': 'system',
                  'content': '''You are a lyrics database. Provide complete, unabridged song lyrics.

STRICT RULES:
1. Output ONLY the lyrics — no title, no artist, no section labels like [Verse] or [Chorus].
2. Include EVERY verse, chorus, bridge, and outro. Do NOT skip or summarize any part.
3. Use a blank line between stanzas.
4. Script instruction: $scriptInstruction
5. If you genuinely do not know this song, respond with exactly: UNKNOWN
6. Do NOT add any commentary before or after the lyrics.''',
                },
                {
                  'role': 'user',
                  'content':
                      'Complete lyrics for "$title"$artistHint. Script: $targetLanguage.',
                }
              ],
              'temperature': 0.1,
              // Large token budget — Garba songs can be 300+ lines
              'max_tokens': 32768,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      var content =
          (data['choices']?[0]?['message']?['content'] as String? ?? '')
              .trim();

      // Strip any accidental <think>...</think> blocks from models that emit them.
      content = _stripThinkTags(content);

      if (content.isEmpty || content.toUpperCase() == 'UNKNOWN') return null;

      // Clean up any stray section labels the model might add despite instructions.
      content = _cleanLyrics(content);

      return LyricsResult(
        title: title,
        artist: artist.isNotEmpty ? artist : null,
        lyrics: content,
        source: 'Groq AI',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Source 1: LRCLIB ───────────────────────────────────────────────────────

  /// Searches LRCLIB for the best match with lyrics.
  Future<LyricsResult?> _searchLrclib(String query) async {
    final uri = Uri.parse(
      'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
    );

    final response = await _client
        .get(uri, headers: {'User-Agent': 'GarbaSongManager/1.0'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final List<dynamic> data = json.decode(response.body);
    if (data.isEmpty) return null;

    for (final track in data) {
      final plainLyrics = track['plainLyrics'] as String?;
      if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
        return LyricsResult(
          title: (track['trackName'] as String?) ?? query,
          artist: track['artistName'] as String?,
          lyrics: plainLyrics.trim(),
          source: 'LRCLIB',
        );
      }
    }

    return null;
  }

  /// Searches LRCLIB and returns ALL matches that have plain lyrics.
  Future<List<LyricsSongMatch>> searchLrclibMultiple(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'GarbaSongManager/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body);
      final List<LyricsSongMatch> matches = [];

      for (final track in data) {
        final plainLyrics = track['plainLyrics'] as String?;
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          final title = (track['trackName'] as String?) ?? 'Unknown Title';
          final artist = (track['artistName'] as String?) ?? 'Unknown Artist';
          final album = track['albumName'] as String?;

          matches.add(LyricsSongMatch(
            title: title,
            artist: artist,
            snippet:
                album != null ? 'Album: $album' : 'Instant Lyrics Available ⚡',
            fullLyrics: plainLyrics.trim(),
            source: 'LRCLIB',
          ));
        }
      }

      return matches;
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts a JSON array string from potentially messy LLM output.
  String _extractJsonArray(String raw) {
    final trimmed = raw.trim();

    // Already starts with [
    if (trimmed.startsWith('[')) {
      final endIdx = trimmed.lastIndexOf(']');
      if (endIdx != -1) return trimmed.substring(0, endIdx + 1);
    }

    // Markdown code block
    final codeBlockRegex = RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```');
    final match = codeBlockRegex.firstMatch(trimmed);
    if (match != null) return match.group(1) ?? '';

    // Any [...] in text
    final arrayRegex = RegExp(r'\[[\s\S]*\]');
    final arrayMatch = arrayRegex.firstMatch(trimmed);
    if (arrayMatch != null) return arrayMatch.group(0) ?? '';

    return '';
  }

  /// Strips `<think>...</think>` reasoning tags from models that emit them.
  String _stripThinkTags(String raw) {
    final thinkRegex =
        RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false);
    var cleaned = raw.replaceAll(thinkRegex, '');
    // Handle unclosed <think> (model cut off mid-thought).
    final unclosedIdx = cleaned.toLowerCase().indexOf('<think>');
    if (unclosedIdx != -1) {
      cleaned = cleaned.substring(0, unclosedIdx);
    }
    return cleaned.trim();
  }

  /// Removes common stray labels the model might add despite instructions.
  String _cleanLyrics(String lyrics) {
    // Remove lines that are purely section labels like [Verse 1], [Chorus], etc.
    final sectionLabel =
        RegExp(r'^\s*\[(?:Verse|Chorus|Bridge|Outro|Intro|Pre-Chorus|Hook)\s*\d*\]\s*$',
            caseSensitive: false, multiLine: true);
    return lyrics.replaceAll(sectionLabel, '').trim();
  }

  void dispose() {
    _client.close();
  }
}

// ── Riverpod Provider ──────────────────────────────────────────────────────────

final lyricsApiProvider = Provider<LyricsApiService>((ref) {
  final service = LyricsApiService();
  ref.onDispose(() => service.dispose());
  return service;
});
