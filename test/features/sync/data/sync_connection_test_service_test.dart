import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/sync/data/providers.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';

void main() {
  test('connection test writes reads and deletes probe object', () async {
    final adapter = _FakeSyncStorageAdapter();
    final service = SyncConnectionTestService(
      deviceIdentityService: DeviceIdentityService(
        store: InMemoryDeviceIdentityStore(deviceId: 'device-1'),
      ),
    );

    final result = await service.testAdapter(adapter);

    expect(result.success, isTrue);
    expect(result.message, 'Connection test passed.');
    expect(adapter.writtenKeys, ['.probe/device-1.json']);
    expect(adapter.deletedKeys, ['.probe/device-1.json']);
    expect(adapter.records, isEmpty);
  });

  test('connection test returns safe typed failure summary', () async {
    final adapter = _FakeSyncStorageAdapter(
      writeError: const SyncAuthException('secret raw message'),
    );
    final service = SyncConnectionTestService(
      deviceIdentityService: DeviceIdentityService(
        store: InMemoryDeviceIdentityStore(deviceId: 'device-2'),
      ),
    );

    final result = await service.testAdapter(adapter);

    expect(result.success, isFalse);
    expect(
      result.message,
      'Connection test failed: authentication rejected.',
    );
    expect(result.message, isNot(contains('secret raw message')));
  });

  test('connection test fails when probe content changes remotely', () async {
    final adapter = _FakeSyncStorageAdapter(tamperReadContent: true);
    final service = SyncConnectionTestService(
      deviceIdentityService: DeviceIdentityService(
        store: InMemoryDeviceIdentityStore(deviceId: 'device-3'),
      ),
    );

    final result = await service.testAdapter(adapter);

    expect(result.success, isFalse);
    expect(
      result.message,
      'Connection test failed: probe content mismatch.',
    );
  });
}

class _FakeSyncStorageAdapter implements SyncStorageAdapter {
  _FakeSyncStorageAdapter({this.writeError, this.tamperReadContent = false});

  final SyncException? writeError;
  final bool tamperReadContent;
  final Map<String, String> records = <String, String>{};
  final List<String> writtenKeys = <String>[];
  final List<String> deletedKeys = <String>[];

  @override
  Future<void> delete(String key) async {
    records.remove(key);
    deletedKeys.add(key);
  }

  @override
  Future<List<SyncStorageRecordRef>> listRecords() async {
    return const <SyncStorageRecordRef>[];
  }

  @override
  Future<String> readText(String key) async {
    final content = records[key];
    if (content == null) {
      throw const SyncRemoteNotFoundException('not found');
    }
    if (tamperReadContent) {
      return '$content-mutated';
    }
    return content;
  }

  @override
  Future<void> writeText({required String key, required String content}) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    records[key] = content;
    writtenKeys.add(key);
  }

  @override
  Future<void> writeTombstone({
    required String key,
    required String content,
  }) async {
    records[key] = content;
  }
}
