import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_api_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_models.dart';
import 'package:record_anywhere/shared/network/bangumi_api_client.dart';

void main() {
  late BangumiApiClient client;
  late BangumiApiService service;
  late DioAdapter adapter;

  setUp(() {
    client = BangumiApiClient(
      userAgent: 'record-anywhere/0.1.0 (test)',
      tokenProvider: () async => null,
    );
    service = BangumiApiService(client);
    adapter = DioAdapter(dio: client.dio);
  });

  group('BangumiApiClient', () {
    test('writes default headers and bearer token for requests', () async {
      client = BangumiApiClient(
        userAgent: 'record-anywhere/0.1.0 (test)',
        tokenProvider: () async => 'secret-token',
      );

      final completer = Completer<void>();
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['Accept'], 'application/json');
            expect(
              options.headers['User-Agent'],
              'record-anywhere/0.1.0 (test)',
            );
            expect(options.headers['Authorization'], 'Bearer secret-token');

            completer.complete();
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 200),
            );
          },
        ),
      );

      await client.get<void>('/v0/me');
      await completer.future;
    });

    test('maps 401 into BangumiUnauthorizedError', () async {
      adapter.onGet(
        '/v0/me',
        (server) => server.reply(401, <String, Object?>{'message': 'nope'}),
      );

      expect(
        service.getMe(),
        throwsA(
          isA<BangumiUnauthorizedError>().having(
            (exception) => exception.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('maps 412 into BangumiBadRequestError', () async {
      adapter.onGet(
        '/v0/subjects/1',
        (server) => server.reply(412, <String, Object?>{'message': 'ua'}),
      );

      expect(
        service.getSubject(1),
        throwsA(
          isA<BangumiBadRequestError>().having(
            (exception) => exception.statusCode,
            'statusCode',
            412,
          ),
        ),
      );
    });

    test('maps connection timeout into BangumiNetworkError', () async {
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

      expect(service.getMe(), throwsA(isA<BangumiNetworkError>()));
    });
  });

  group('BangumiApiService', () {
    test('searchSubjects parses paged result payload', () async {
      adapter.onPost(
        '/v0/search/subjects',
        (server) => server.reply(200, <String, Object?>{
          'total': 1,
          'limit': 20,
          'offset': 0,
          'data': <Object?>[
            <String, Object?>{
              'id': 1,
              'type': 2,
              'name': 'Neon Genesis Evangelion',
              'name_cn': '新世纪福音战士',
              'summary': 'test summary',
              'date': '1995-10-04',
              'images': <String, Object?>{
                'common': 'https://example.com/poster.jpg',
              },
              'eps': 26,
            },
          ],
        }),
        queryParameters: <String, Object?>{'limit': 20, 'offset': 0},
        data: <String, Object?>{
          'keyword': 'eva',
          'filter': <String, Object?>{
            'type': <int>[2],
          },
        },
      );

      final result = await service.searchSubjects(
        'eva',
        filter: <String, Object?>{
          'type': <int>[2],
        },
      );

      expect(result.total, 1);
      expect(result.data, hasLength(1));
      expect(result.data.first.nameCn, '新世纪福音战士');
      expect(result.data.first.images.common, 'https://example.com/poster.jpg');
    });

    test(
      'getSubject caches requests within TTL and de-duplicates concurrency',
      () async {
        var requestCount = 0;

        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount += 1;
              handler.next(options);
            },
          ),
        );

        adapter.onGet(
          '/v0/subjects/42',
          (server) => server.reply(200, <String, Object?>{
            'id': 42,
            'type': 6,
            'name': 'Arrival',
            'summary': 'A sci-fi film',
            'date': '2016-09-01',
            'images': <String, Object?>{
              'common': 'https://example.com/arrival.jpg',
            },
          }),
        );

        final results = await Future.wait<BangumiSubjectDto>(
          <Future<BangumiSubjectDto>>[
            service.getSubject(42),
            service.getSubject(42),
          ],
        );

        final cached = await service.getSubject(42);

        expect(results.first.id, 42);
        expect(results.last.id, 42);
        expect(cached.name, 'Arrival');
        expect(requestCount, 1);
      },
    );

    test('getSubject refetches after cache expiry', () async {
      var now = DateTime(2026, 4, 21, 12, 0, 0);
      client = BangumiApiClient(
        userAgent: 'record-anywhere/0.1.0 (test)',
        tokenProvider: () async => null,
      );
      service = BangumiApiService(
        client,
        now: () => now,
        subjectCacheTtl: const Duration(seconds: 300),
      );
      adapter = DioAdapter(dio: client.dio);

      var requestCount = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;
            handler.next(options);
          },
        ),
      );

      adapter.onGet(
        '/v0/subjects/7',
        (server) => server.reply(200, <String, Object?>{
          'id': 7,
          'type': 1,
          'name': 'Book',
        }),
      );

      await service.getSubject(7);
      now = now.add(const Duration(seconds: 301));
      await service.getSubject(7);

      expect(requestCount, 2);
    });

    test('getMe parses user payload', () async {
      adapter.onGet(
        '/v0/me',
        (server) => server.reply(200, <String, Object?>{
          'id': 9,
          'username': 'lingshi',
          'nickname': 'Ling',
          'sign': 'Hello',
          'avatar': <String, Object?>{
            'large': 'https://example.com/avatar.jpg',
          },
        }),
      );

      final user = await service.getMe();

      expect(user.id, 9);
      expect(user.username, 'lingshi');
      expect(user.avatar?.large, 'https://example.com/avatar.jpg');
    });

    test('getCollection parses collection payload', () async {
      adapter.onGet(
        '/v0/users/lingshi/collections/42',
        (server) => server.reply(200, <String, Object?>{
          'subject_id': 42,
          'type': 2,
          'rate': 9,
          'comment': 'Great',
          'private': true,
          'tags': <String>['mecha', 'classic'],
          'subject': <String, Object?>{'id': 42, 'type': 2, 'name': 'Eva'},
        }),
      );

      final collection = await service.getCollection('lingshi', 42);

      expect(collection.subjectId, 42);
      expect(collection.type, 2);
      expect(collection.tags, containsAll(<String>['mecha', 'classic']));
      expect(collection.subject?.name, 'Eva');
    });
  });
}
