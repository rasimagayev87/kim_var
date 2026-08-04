enum StorageFailure {
  fileTooLarge,
  invalidContentType,
  uploadFailed,
  downloadUrlFailed,
  deleteFailed,
  permissionDenied,
  unauthenticated,
  unknown,
}

class StorageException implements Exception {
  final StorageFailure type;
  final String message;
  final Object? cause;

  const StorageException(this.type, this.message, {this.cause});

  @override
  String toString() => 'StorageException($type): $message';
}
