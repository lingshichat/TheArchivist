import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/sync/data/s3_storage_adapter.dart';
import 'package:record_anywhere/features/sync/data/sync_exception.dart';
import 'package:record_anywhere/features/sync/data/sync_models.dart';
import 'package:record_anywhere/features/sync/data/sync_storage_adapter.dart';
import 'package:record_anywhere/shared/network/s3_api_client.dart';

void main() {
  group('S3ApiClient request builder', () {
    test(
      'path-style object read keeps bucket in path and signs the request',
      () async {
        final harness = _S3Harness(
          addressingStyle: S3AddressingStyle.pathStyle,
        );
        harness.transport.enqueue(
          _MockStep.success(
            method: 'GET',
            body: '{"ok":true}',
            assertRequest: (options) {
              expect(options.uri.scheme, 'https');
              expect(options.uri.host, 's3.example.com');
              expect(
                options.uri.path,
                '/demo-bucket/record-anywhere-sync/entities/mediaItem/movie%252F1.json',
              );
              expect(_headerValue(options, 'authorization'), isNotNull);
              expect(
                _headerValue(options, 'authorization'),
                startsWith('AWS4-HMAC-SHA256 '),
              );
              expect(_headerValue(options, 'x-amz-date'), isNotNull);
            },
          ),
        );

        final response = await harness.client.getText(
          'entities/mediaItem/movie%2F1.json',
        );

        expect(response.data, '{"ok":true}');
        harness.expectNoPendingRequests();
      },
    );

    test(
      'virtual-hosted listObjectsV2 moves bucket into host and preserves continuation token',
      () async {
        final harness = _S3Harness(
          addressingStyle: S3AddressingStyle.virtualHostedStyle,
        );
        harness.transport.enqueue(
          _MockStep.success(
            method: 'GET',
            body: _listXml(contents: const <_ListEntry>[]),
            assertRequest: (options) {
              expect(options.uri.scheme, 'https');
              expect(options.uri.host, 'demo-bucket.s3.example.com');
              expect(_normalizedPath(options.uri.path), '/');
              expect(options.uri.queryParameters['list-type'], '2');
              expect(
                options.uri.queryParameters['prefix'],
                'record-anywhere-sync/entities/',
              );
              expect(
                options.uri.queryParameters['continuation-token'],
                'page-2',
              );
              expect(
                _headerValue(options, 'authorization'),
                startsWith('AWS4-HMAC-SHA256 '),
              );
            },
          ),
        );

        await harness.client.listObjectsV2(
          prefix: 'entities/',
          continuationToken: 'page-2',
        );

        harness.expectNoPendingRequests();
      },
    );
  });

  group('S3StorageAdapter', () {
    late _S3Harness harness;

    setUp(() {
      harness = _S3Harness(addressingStyle: S3AddressingStyle.pathStyle);
    });

    tearDown(() {
      harness.expectNoPendingRequests();
    });

    test('list/read/write/delete/tombstone follows unified sync key contract', () async {
      final entityEnvelope = SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItem,
        entityId: 'movie/1',
        updatedAt: DateTime.utc(2026, 4, 23, 12, 0, 0),
        deviceId: 'device-a',
        payload: const <String, Object?>{'title': 'Arrival'},
      );
      final tombstoneEnvelope = SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItem,
        entityId: 'movie/1',
        updatedAt: DateTime.utc(2026, 4, 23, 13, 0, 0),
        deletedAt: DateTime.utc(2026, 4, 23, 13, 0, 0),
        deviceId: 'device-a',
        payload: const <String, Object?>{'title': 'Arrival'},
      );
      final entityContent = entityEnvelope.toJsonString();
      final tombstoneContent = tombstoneEnvelope.toJsonString();

      harness.transport
        ..enqueue(
          _MockStep.success(
            method: 'PUT',
            statusCode: 200,
            assertRequest: (options) {
              expect(
                options.uri.path,
                '/demo-bucket/record-anywhere-sync/entities/mediaItem/movie%252F1.json',
              );
              expect(options.data, entityContent);
            },
          ),
        )
        ..enqueue(
          _MockStep.success(
            method: 'PUT',
            statusCode: 200,
            assertRequest: (options) {
              expect(
                options.uri.path,
                '/demo-bucket/record-anywhere-sync/tombstones/mediaItem/movie%252F1.json',
              );
              expect(options.data, tombstoneContent);
            },
          ),
        )
        ..enqueue(
          _MockStep.success(
            method: 'GET',
            body: _listXml(
              contents: <_ListEntry>[
                _ListEntry(
                  key: 'record-anywhere-sync/entities/mediaItem/movie%2F1.json',
                  lastModified: DateTime.utc(2026, 4, 23, 12, 0, 0),
                ),
              ],
            ),
            assertRequest: (options) {
              expect(options.uri.queryParameters['list-type'], '2');
              expect(
                options.uri.queryParameters['prefix'],
                'record-anywhere-sync/entities/',
              );
            },
          ),
        )
        ..enqueue(
          _MockStep.success(
            method: 'GET',
            body: _listXml(
              contents: <_ListEntry>[
                _ListEntry(
                  key:
                      'record-anywhere-sync/tombstones/mediaItem/movie%2F1.json',
                  lastModified: DateTime.utc(2026, 4, 23, 13, 0, 0),
                ),
              ],
            ),
            assertRequest: (options) {
              expect(options.uri.queryParameters['list-type'], '2');
              expect(
                options.uri.queryParameters['prefix'],
                'record-anywhere-sync/tombstones/',
              );
            },
          ),
        )
        ..enqueue(
          _MockStep.success(
            method: 'GET',
            body: entityContent,
            assertRequest: (options) {
              expect(
                options.uri.path,
                '/demo-bucket/record-anywhere-sync/entities/mediaItem/movie%252F1.json',
              );
            },
          ),
        )
        ..enqueue(
          _MockStep.success(
            method: 'DELETE',
            statusCode: 204,
            assertRequest: (options) {
              expect(
                options.uri.path,
                '/demo-bucket/record-anywhere-sync/entities/mediaItem/movie%252F1.json',
              );
            },
          ),
        );

      await harness.adapter.writeText(
        key: 'entities/mediaItem/movie%2F1.json',
        content: entityContent,
      );
      await harness.adapter.writeTombstone(
        key: 'tombstones/mediaItem/movie%2F1.json',
        content: tombstoneContent,
      );
      final refs = await harness.adapter.listRecords();
      final readBack = await harness.adapter.readText(
        'entities/mediaItem/movie%2F1.json',
      );
      await harness.adapter.delete('entities/mediaItem/movie%2F1.json');

      expect(refs, hasLength(2));
      expect(
        refs,
        contains(
          isA<SyncStorageRecordRef>()
              .having(
                (ref) => ref.key,
                'key',
                'entities/mediaItem/movie%2F1.json',
              )
              .having((ref) => ref.kind, 'kind', SyncStorageRecordKind.entity)
              .having(
                (ref) => ref.updatedAt,
                'updatedAt',
                DateTime.utc(2026, 4, 23, 12, 0, 0),
              ),
        ),
      );
      expect(
        refs,
        contains(
          isA<SyncStorageRecordRef>()
              .having(
                (ref) => ref.key,
                'key',
                'tombstones/mediaItem/movie%2F1.json',
              )
              .having(
                (ref) => ref.kind,
                'kind',
                SyncStorageRecordKind.tombstone,
              )
              .having(
                (ref) => ref.updatedAt,
                'updatedAt',
                DateTime.utc(2026, 4, 23, 13, 0, 0),
              ),
        ),
      );
      expect(readBack, entityContent);
    });

    test(
      'listRecords follows ListObjectsV2 continuation tokens until all pages are collected',
      () async {
        harness.transport
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(
                contents: <_ListEntry>[
                  _ListEntry(
                    key: 'record-anywhere-sync/entities/mediaItem/a.json',
                    lastModified: DateTime.utc(2026, 4, 23, 8, 0, 0),
                  ),
                ],
                isTruncated: true,
                nextContinuationToken: 'entities-page-2',
              ),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['prefix'],
                  'record-anywhere-sync/entities/',
                );
                expect(
                  options.uri.queryParameters.containsKey('continuation-token'),
                  isFalse,
                );
              },
            ),
          )
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(
                contents: <_ListEntry>[
                  _ListEntry(
                    key: 'record-anywhere-sync/entities/mediaItem/b.json',
                    lastModified: DateTime.utc(2026, 4, 23, 9, 0, 0),
                  ),
                ],
              ),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['continuation-token'],
                  'entities-page-2',
                );
              },
            ),
          )
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(
                contents: <_ListEntry>[
                  _ListEntry(
                    key: 'record-anywhere-sync/tombstones/mediaItem/c.json',
                    lastModified: DateTime.utc(2026, 4, 23, 10, 0, 0),
                  ),
                ],
                isTruncated: true,
                nextContinuationToken: 'tombstones-page-2',
              ),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['prefix'],
                  'record-anywhere-sync/tombstones/',
                );
                expect(
                  options.uri.queryParameters.containsKey('continuation-token'),
                  isFalse,
                );
              },
            ),
          )
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(
                contents: <_ListEntry>[
                  _ListEntry(
                    key: 'record-anywhere-sync/tombstones/mediaItem/d.json',
                    lastModified: DateTime.utc(2026, 4, 23, 11, 0, 0),
                  ),
                ],
              ),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['continuation-token'],
                  'tombstones-page-2',
                );
              },
            ),
          );

        final refs = await harness.adapter.listRecords();

        expect(refs, hasLength(4));
        expect(
          refs.map((ref) => ref.key),
          containsAll(<String>[
            'entities/mediaItem/a.json',
            'entities/mediaItem/b.json',
            'tombstones/mediaItem/c.json',
            'tombstones/mediaItem/d.json',
          ]),
        );
      },
    );

    test(
      'listRecords returns empty when the configured bucket prefix has no objects',
      () async {
        harness.transport
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(contents: const <_ListEntry>[]),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['prefix'],
                  'record-anywhere-sync/entities/',
                );
              },
            ),
          )
          ..enqueue(
            _MockStep.success(
              method: 'GET',
              body: _listXml(contents: const <_ListEntry>[]),
              assertRequest: (options) {
                expect(
                  options.uri.queryParameters['prefix'],
                  'record-anywhere-sync/tombstones/',
                );
              },
            ),
          );

        final refs = await harness.adapter.listRecords();

        expect(refs, isEmpty);
      },
    );

    for (final statusCode in <int>[401, 403]) {
      test('maps $statusCode into SyncAuthException', () async {
        harness.transport.enqueue(
          _MockStep.badResponse(
            method: 'GET',
            statusCode: statusCode,
            body: '<Error><Code>AccessDenied</Code></Error>',
          ),
        );

        await expectLater(
          harness.adapter.readText('entities/mediaItem/a.json'),
          throwsA(isA<SyncAuthException>()),
        );
      });
    }

    test('maps 404 into SyncRemoteNotFoundException on missing read', () async {
      harness.transport.enqueue(
        _MockStep.badResponse(
          method: 'GET',
          statusCode: 404,
          body: '<Error><Code>NoSuchKey</Code></Error>',
          assertRequest: (options) {
            expect(
              options.uri.path,
              '/demo-bucket/record-anywhere-sync/entities/mediaItem/a.json',
            );
          },
        ),
      );

      await expectLater(
        harness.adapter.readText('entities/mediaItem/a.json'),
        throwsA(isA<SyncRemoteNotFoundException>()),
      );
    });

    test('maps connection timeout into SyncNetworkException', () async {
      harness.transport.enqueue(
        _MockStep.transportError(
          method: 'GET',
          errorType: DioExceptionType.connectionTimeout,
          assertRequest: (options) {
            expect(
              options.uri.path,
              '/demo-bucket/record-anywhere-sync/entities/mediaItem/a.json',
            );
          },
        ),
      );

      await expectLater(
        harness.adapter.readText('entities/mediaItem/a.json'),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('maps 5xx into SyncServerException', () async {
      harness.transport.enqueue(
        _MockStep.badResponse(
          method: 'DELETE',
          statusCode: 503,
          body: '<Error><Code>SlowDown</Code></Error>',
        ),
      );

      await expectLater(
        harness.adapter.delete('entities/mediaItem/a.json'),
        throwsA(isA<SyncServerException>()),
      );
    });

    test(
      'writeText allows repeated overwrite of the same object key',
      () async {
        final firstContent = SyncEntityEnvelope(
          entityType: SyncEntityType.mediaItem,
          entityId: 'movie/1',
          updatedAt: DateTime.utc(2026, 4, 23, 12, 0, 0),
          deviceId: 'device-a',
          payload: const <String, Object?>{'title': 'Arrival'},
        ).toJsonString();
        final secondContent = SyncEntityEnvelope(
          entityType: SyncEntityType.mediaItem,
          entityId: 'movie/1',
          updatedAt: DateTime.utc(2026, 4, 23, 12, 5, 0),
          deviceId: 'device-a',
          payload: const <String, Object?>{'title': 'Arrival (Updated)'},
        ).toJsonString();

        harness.transport
          ..enqueue(
            _MockStep.success(
              method: 'PUT',
              statusCode: 200,
              assertRequest: (options) {
                expect(options.data, firstContent);
              },
            ),
          )
          ..enqueue(
            _MockStep.success(
              method: 'PUT',
              statusCode: 200,
              assertRequest: (options) {
                expect(options.data, secondContent);
              },
            ),
          )
          ..enqueue(_MockStep.success(method: 'GET', body: secondContent));

        await harness.adapter.writeText(
          key: 'entities/mediaItem/movie%2F1.json',
          content: firstContent,
        );
        await harness.adapter.writeText(
          key: 'entities/mediaItem/movie%2F1.json',
          content: secondContent,
        );
        final readBack = await harness.adapter.readText(
          'entities/mediaItem/movie%2F1.json',
        );

        expect(readBack, secondContent);
      },
    );

    test(
      'delete stays idempotent when the remote service accepts repeated deletes',
      () async {
        harness.transport
          ..enqueue(_MockStep.success(method: 'DELETE', statusCode: 204))
          ..enqueue(_MockStep.success(method: 'DELETE', statusCode: 204));

        await harness.adapter.delete('entities/mediaItem/a.json');
        await harness.adapter.delete('entities/mediaItem/a.json');

        expect(
          harness.transport.requests.where(
            (request) => request.method == 'DELETE',
          ),
          hasLength(2),
        );
      },
    );
  });
}

/// These tests freeze the WP4 transport/adapter seam so the parallel workers
/// can converge on one contract instead of each inventing their own harness.
class _S3Harness {
  _S3Harness({required S3AddressingStyle addressingStyle}) {
    client = S3ApiClient(
      requestConfig: S3RequestConfig(
        endpoint: Uri.parse('https://s3.example.com'),
        region: 'us-east-1',
        bucket: 'demo-bucket',
        rootPrefix: 'record-anywhere-sync',
        addressingStyle: addressingStyle,
      ),
      credentialsProvider: () async => S3Credentials(
        accessKey: 'test-access-key',
        secretKey: 'test-secret-key',
      ),
      userAgent: 'record-anywhere/0.1.0 (test)',
    );
    transport = _MockTransport(client.dio);
    adapter = S3StorageAdapter(client: client);
  }

  late final S3ApiClient client;
  late final S3StorageAdapter adapter;
  late final _MockTransport transport;

  void expectNoPendingRequests() {
    transport.expectNoPendingRequests();
  }
}

class _MockTransport {
  _MockTransport(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (_steps.isEmpty) {
            fail('Unexpected request: ${options.method} ${options.uri}');
          }

          final step = _steps.removeAt(0);
          step.dispatch(options, handler);
        },
      ),
    );
  }

  final List<_MockStep> _steps = <_MockStep>[];
  final List<RequestOptions> requests = <RequestOptions>[];

  void enqueue(_MockStep step) {
    _steps.add(step);
  }

  void expectNoPendingRequests() {
    expect(_steps, isEmpty);
  }
}

class _MockStep {
  _MockStep.success({
    required this.method,
    this.statusCode = 200,
    this.body = '',
    this.assertRequest,
  }) : _errorType = null;

  _MockStep.badResponse({
    required this.method,
    required this.statusCode,
    this.body = '',
    this.assertRequest,
  }) : _errorType = DioExceptionType.badResponse;

  _MockStep.transportError({
    required this.method,
    required DioExceptionType errorType,
    this.assertRequest,
  }) : statusCode = null,
       body = '',
       _errorType = errorType;

  final String method;
  final int? statusCode;
  final String body;
  final void Function(RequestOptions options)? assertRequest;
  final DioExceptionType? _errorType;

  void dispatch(RequestOptions options, RequestInterceptorHandler handler) {
    expect(options.method, method);
    assertRequest?.call(options);

    if (_errorType == null) {
      handler.resolve(
        Response<String>(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        ),
      );
      return;
    }

    final response = statusCode == null
        ? null
        : Response<String>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          );
    handler.reject(
      DioException(
        requestOptions: options,
        response: response,
        type: _errorType,
      ),
    );
  }
}

class _ListEntry {
  const _ListEntry({required this.key, required this.lastModified});

  final String key;
  final DateTime lastModified;
}

String _listXml({
  required List<_ListEntry> contents,
  bool isTruncated = false,
  String? nextContinuationToken,
}) {
  final contentsXml = contents
      .map(
        (entry) =>
            '''
  <Contents>
    <Key>${entry.key}</Key>
    <LastModified>${entry.lastModified.toIso8601String()}</LastModified>
  </Contents>''',
      )
      .join('\n');

  return '''
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult>
  <IsTruncated>${isTruncated ? 'true' : 'false'}</IsTruncated>
  ${nextContinuationToken == null ? '' : '<NextContinuationToken>$nextContinuationToken</NextContinuationToken>'}
  $contentsXml
</ListBucketResult>
''';
}

String? _headerValue(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

String _normalizedPath(String path) {
  if (path.isEmpty) {
    return '/';
  }

  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  return trimmed.isEmpty ? '/' : trimmed;
}
