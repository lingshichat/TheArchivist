import 'package:dio/dio.dart';

import '../../../shared/network/bangumi_api_client.dart';
import 'bangumi_models.dart';

class BangumiApiService {
  BangumiApiService(
    this._client, {
    DateTime Function()? now,
    Duration subjectCacheTtl = const Duration(seconds: 300),
  }) : _now = now ?? DateTime.now,
       _subjectCacheTtl = subjectCacheTtl;

  final BangumiApiClient _client;
  final DateTime Function() _now;
  final Duration _subjectCacheTtl;

  final Map<int, _SubjectCacheEntry> _subjectCache =
      <int, _SubjectCacheEntry>{};
  final Map<int, Future<BangumiSubjectDto>> _pendingSubjects =
      <int, Future<BangumiSubjectDto>>{};

  Future<BangumiSearchResult> searchSubjects(
    String keyword, {
    Map<String, Object?>? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw ArgumentError.value(
        keyword,
        'keyword',
        'Bangumi search keyword cannot be empty.',
      );
    }

    final response = await _runRequest(
      () => _client.post<Map<String, dynamic>>(
        '/v0/search/subjects',
        queryParameters: <String, dynamic>{
          'limit': limit.clamp(1, 50),
          'offset': offset < 0 ? 0 : offset,
        },
        data: <String, Object?>{
          'keyword': normalizedKeyword,
          if (filter != null && filter.isNotEmpty)
            'filter': _compactMap(filter),
        },
      ),
    );

    return BangumiSearchResult.fromJson(
      Map<String, Object?>.from(response.data ?? const <String, Object?>{}),
    );
  }

  Future<BangumiSubjectDto> getSubject(int id) async {
    final cached = _subjectCache[id];
    if (cached != null && !_isExpired(cached.cachedAt)) {
      return cached.subject;
    }

    final pending = _pendingSubjects[id];
    if (pending != null) {
      return pending;
    }

    final future = _fetchSubject(id);
    _pendingSubjects[id] = future;

    try {
      return await future;
    } finally {
      _pendingSubjects.remove(id);
    }
  }

  Future<BangumiUserDto> getMe() async {
    final response = await _runRequest(
      () => _client.get<Map<String, dynamic>>('/v0/me'),
    );
    return BangumiUserDto.fromJson(
      Map<String, Object?>.from(response.data ?? const <String, Object?>{}),
    );
  }

  Future<void> updateCollection(
    int subjectId, {
    required int type,
    int? rate,
    String? comment,
    bool? isPrivate,
    List<String>? tags,
  }) async {
    await _runRequest(
      () => _client.post<void>(
        '/v0/users/-/collections/$subjectId',
        data: _compactMap(<String, Object?>{
          'type': type,
          'rate': rate,
          'comment': _normalizeOptional(comment),
          'private': isPrivate,
          'tags': _normalizeTags(tags),
        }),
      ),
    );
  }

  Future<void> patchCollection(int subjectId, Map<String, Object?> body) async {
    await _runRequest(
      () => _client.patch<void>(
        '/v0/users/-/collections/$subjectId',
        data: _compactMap(body),
      ),
    );
  }

  Future<BangumiCollectionDto> getCollection(
    String username,
    int subjectId,
  ) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(
        username,
        'username',
        'Bangumi username cannot be empty.',
      );
    }

    final response = await _runRequest(
      () => _client.get<Map<String, dynamic>>(
        '/v0/users/$normalizedUsername/collections/$subjectId',
      ),
    );

    return BangumiCollectionDto.fromJson(
      Map<String, Object?>.from(response.data ?? const <String, Object?>{}),
    );
  }

  Future<BangumiSubjectDto> _fetchSubject(int id) async {
    final response = await _runRequest(
      () => _client.get<Map<String, dynamic>>('/v0/subjects/$id'),
    );

    final subject = BangumiSubjectDto.fromJson(
      Map<String, Object?>.from(response.data ?? const <String, Object?>{}),
    );

    _subjectCache[id] = _SubjectCacheEntry(subject: subject, cachedAt: _now());
    return subject;
  }

  bool _isExpired(DateTime cachedAt) {
    return _now().difference(cachedAt) > _subjectCacheTtl;
  }

  Map<String, Object?> _compactMap(Map<String, Object?> source) {
    return source.entries
        .where((entry) => entry.value != null)
        .fold<Map<String, Object?>>(<String, Object?>{}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        });
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String>? _normalizeTags(List<String>? tags) {
    if (tags == null) {
      return null;
    }

    final normalized = tags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return normalized.isEmpty ? null : normalized;
  }

  Future<T> _runRequest<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw _client.toApiException(error);
    }
  }
}

class _SubjectCacheEntry {
  const _SubjectCacheEntry({required this.subject, required this.cachedAt});

  final BangumiSubjectDto subject;
  final DateTime cachedAt;
}
