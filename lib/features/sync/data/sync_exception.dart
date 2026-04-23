sealed class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SyncNetworkException extends SyncException {
  const SyncNetworkException(super.message);
}

final class SyncAuthException extends SyncException {
  const SyncAuthException(super.message);
}

final class SyncServerException extends SyncException {
  const SyncServerException(super.message);
}

final class SyncRemoteNotFoundException extends SyncException {
  const SyncRemoteNotFoundException(super.message);
}

final class SyncFormatException extends SyncException {
  const SyncFormatException(super.message);
}

final class SyncPartialBatchException extends SyncException {
  const SyncPartialBatchException({
    required String message,
    required this.failedCount,
  }) : super(message);

  final int failedCount;
}
