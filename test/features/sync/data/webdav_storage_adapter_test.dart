import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:record_anywhere/features/sync/data/sync_exception.dart';
import 'package:record_anywhere/features/sync/data/sync_models.dart';
import 'package:record_anywhere/features/sync/data/sync_storage_adapter.dart';
import 'package:record_anywhere/features/sync/data/webdav_storage_adapter.dart';
import 'package:record_anywhere/shared/network/webdav_api_client.dart';

void main() {
  late WebDavApiClient client;
  late WebDavStorageAdapter adapter;
  late DioAdapter dioAdapter;
  const plainTextHeaders = <String, List<String>>{
    Headers.contentTypeHeader: <String>['text/plain'],
  };

  void stubCustomMethod({
    required String method,
    required String path,
    required int statusCode,
    required String body,
  }) {
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == method && options.path == path) {
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: statusCode,
                data: body,
              ),
            );
            return;
          }

          handler.next(options);
        },
      ),
    );
  }

  setUp(() {
    client = WebDavApiClient(
      baseUri: Uri.parse('https://dav.example.com/remote.php/dav/files/demo/'),
      userAgent: 'record-anywhere/0.1.0 (test)',
      authProvider: () async =>
          const WebDavAuth(username: 'demo', password: 'secret'),
    );
    dioAdapter = DioAdapter(
      dio: client.dio,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
    adapter = WebDavStorageAdapter(
      client: client,
      rootPath: 'record-anywhere-sync',
    );
  });

  test('list/read/write/delete follows unified sync key contract', () async {
    final envelope = SyncEntityEnvelope(
      entityType: SyncEntityType.mediaItem,
      entityId: 'movie/1',
      updatedAt: DateTime.utc(2026, 4, 23, 12, 0, 0),
      deviceId: 'device-a',
      payload: const <String, Object?>{'title': 'Arrival'},
    );
    final content = envelope.toJsonString();
    final key = 'entities/mediaItem/movie%2F1.json';
    const rootPath = 'record-anywhere-sync';
    const remotePath = '$rootPath/entities/mediaItem/movie%252F1.json';
    final listXml = '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/demo/record-anywhere-sync/entities/mediaItem/movie%252F1.json</d:href>
    <d:propstat>
      <d:prop>
        <d:getlastmodified>Thu, 23 Apr 2026 12:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

    stubCustomMethod(
      method: 'MKCOL',
      path: rootPath,
      statusCode: 201,
      body: '',
    );
    stubCustomMethod(
      method: 'MKCOL',
      path: '$rootPath/entities',
      statusCode: 201,
      body: '',
    );
    stubCustomMethod(
      method: 'MKCOL',
      path: '$rootPath/entities/mediaItem',
      statusCode: 201,
      body: '',
    );
    dioAdapter.onPut(
      remotePath,
      (server) => server.reply(201, ''),
      data: content,
    );
    stubCustomMethod(
      method: 'PROPFIND',
      path: '$rootPath/entities',
      statusCode: 207,
      body: listXml,
    );
    stubCustomMethod(
      method: 'PROPFIND',
      path: '$rootPath/tombstones',
      statusCode: 404,
      body: '',
    );
    dioAdapter.onGet(
      remotePath,
      (server) => server.reply(200, content, headers: plainTextHeaders),
    );
    dioAdapter.onDelete(remotePath, (server) => server.reply(204, ''));

    await adapter.writeText(key: key, content: content);
    final refs = await adapter.listRecords();
    final readBack = await adapter.readText(key);
    await adapter.delete(key);

    expect(refs, hasLength(1));
    expect(refs.first.key, key);
    expect(refs.first.kind, SyncStorageRecordKind.entity);
    expect(refs.first.updatedAt, DateTime.utc(2026, 4, 23, 12, 0, 0));
    expect(readBack, content);
  });

  test('maps 401 into SyncAuthException', () async {
    dioAdapter.onGet(
      'record-anywhere-sync/entities/mediaItem/a.json',
      (server) => server.reply(401, 'nope', headers: plainTextHeaders),
    );

    expect(
      adapter.readText('entities/mediaItem/a.json'),
      throwsA(isA<SyncAuthException>()),
    );
  });

  test('maps 404 into SyncRemoteNotFoundException on missing read', () async {
    dioAdapter.onGet(
      'record-anywhere-sync/entities/mediaItem/a.json',
      (server) => server.reply(404, '', headers: plainTextHeaders),
    );

    expect(
      adapter.readText('entities/mediaItem/a.json'),
      throwsA(isA<SyncRemoteNotFoundException>()),
    );
  });

  test('writeTombstone is idempotent when collections already exist', () async {
    final envelope = SyncEntityEnvelope(
      entityType: SyncEntityType.mediaItem,
      entityId: 'deleted-item',
      updatedAt: DateTime.utc(2026, 4, 23, 13, 0, 0),
      deviceId: 'device-a',
      deletedAt: DateTime.utc(2026, 4, 23, 13, 0, 0),
      payload: const <String, Object?>{'title': 'Deleted'},
    );
    final content = jsonEncode(envelope.toJson());
    const rootPath = 'record-anywhere-sync';
    const remotePath = '$rootPath/tombstones/mediaItem/deleted-item.json';

    stubCustomMethod(
      method: 'MKCOL',
      path: rootPath,
      statusCode: 405,
      body: '',
    );
    stubCustomMethod(
      method: 'MKCOL',
      path: '$rootPath/tombstones',
      statusCode: 405,
      body: '',
    );
    stubCustomMethod(
      method: 'MKCOL',
      path: '$rootPath/tombstones/mediaItem',
      statusCode: 405,
      body: '',
    );
    dioAdapter.onPut(
      remotePath,
      (server) => server.reply(201, ''),
      data: content,
    );

    await adapter.writeTombstone(
      key: 'tombstones/mediaItem/deleted-item.json',
      content: content,
    );
  });

  test('maps timeout into SyncNetworkException', () async {
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );

    expect(adapter.listRecords(), throwsA(isA<SyncNetworkException>()));
  });

  test('maps 5xx into SyncServerException', () async {
    dioAdapter.onDelete(
      'record-anywhere-sync/entities/mediaItem/a.json',
      (server) => server.reply(503, 'busy'),
    );

    expect(
      adapter.delete('entities/mediaItem/a.json'),
      throwsA(isA<SyncServerException>()),
    );
  });
}
