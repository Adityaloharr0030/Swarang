/// Application-specific exception hierarchy.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Exception thrown when a database operation fails.
class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

/// Exception thrown when form validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Exception thrown during backup/restore operations.
class BackupException extends AppException {
  const BackupException(super.message);
}

/// Exception thrown when file operations fail.
class FileException extends AppException {
  const FileException(super.message);
}

/// Exception thrown when a requested record is not found.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Exception thrown when a duplicate relationship is detected.
class DuplicateException extends AppException {
  const DuplicateException(super.message);
}
