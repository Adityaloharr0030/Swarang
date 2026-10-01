import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies attached photos and PDFs into the app's local storage
/// so they remain available offline.
class FileStorageService {
  static FileStorageService? _instance;
  String? _basePath;

  FileStorageService._();

  static FileStorageService get instance {
    _instance ??= FileStorageService._();
    return _instance!;
  }

  /// Returns the base directory for stored files.
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final dir = await getApplicationDocumentsDirectory();
    _basePath = dir.path;
    return _basePath!;
  }

  /// Returns the directory for song photos (creates if needed).
  Future<Directory> get _photosDir async {
    final dir = Directory(p.join(await basePath, 'song_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns the directory for song PDFs (creates if needed).
  Future<Directory> get _pdfsDir async {
    final dir = Directory(p.join(await basePath, 'song_pdfs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a photo to local storage and returns the new path.
  /// Uses a unique timestamp-based filename to avoid collisions.
  Future<String> savePhoto(String sourcePath) async {
    final dir = await _photosDir;
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(dir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Copies a PDF to local storage and returns the new path.
  Future<String> savePdf(String sourcePath) async {
    final dir = await _pdfsDir;
    final fileName = 'pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final destPath = p.join(dir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Deletes a saved photo file.
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes multiple files.
  Future<void> deleteFiles(List<String> filePaths) async {
    for (final path in filePaths) {
      await deleteFile(path);
    }
  }

  /// Checks if a file exists.
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }
}
