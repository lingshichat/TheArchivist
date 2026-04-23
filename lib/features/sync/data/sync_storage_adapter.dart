enum SyncStorageRecordKind { entity, tombstone }

class SyncStorageRecordRef {
  const SyncStorageRecordRef({
    required this.key,
    required this.kind,
    required this.updatedAt,
  });

  final String key;
  final SyncStorageRecordKind kind;
  final DateTime updatedAt;
}

abstract class SyncStorageAdapter {
  Future<List<SyncStorageRecordRef>> listRecords();

  Future<String> readText(String key);

  Future<void> writeText({required String key, required String content});

  Future<void> writeTombstone({required String key, required String content});

  Future<void> delete(String key);
}
