import 'package:dio/dio.dart';

import '../../../shared/network/bangumi_api_client.dart';
import 'bangumi_models.dart';
import 'bangumi_type_mapper.dart';

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

  Future<BangumiCollectionPage> listCollections(
    String username, {
    int limit = 30,
    int offset = 0,
    int? subjectType,
  }) async {
    /*
     * ========================================================================
     * 步骤1：拉取 Bangumi 用户收藏列表
     * ========================================================================
     * 目标：
     *   1) 为首次导入、启动恢复、手动同步提供统一分页入口
     *   2) 在网络层外继续暴露稳定的 DTO 列表合同
     */

    // 1.1 归一化用户名和类型过滤，非法输入在发请求前直接拒绝
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(
        username,
        'username',
        'Bangumi username cannot be empty.',
      );
    }

    final normalizedSubjectType = _normalizeSubjectType(subjectType);

    // 1.2 发起分页请求，并保留列表项里的 subject / status / score 字段
    final response = await _runRequest(
      () => _client.get<Map<String, dynamic>>(
        '/v0/users/$normalizedUsername/collections',
        queryParameters: _compactMap(<String, Object?>{
          'limit': limit <= 0 ? 30 : limit.clamp(1, 50),
          'offset': offset < 0 ? 0 : offset,
          'subject_type': normalizedSubjectType,
        }),
      ),
    );

    // 1.3 把分页响应转换成类型化 Page DTO，供 pull 层继续翻页
    return BangumiCollectionPage.fromJson(
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
    int? epStatus,
  }) async {
    await _runRequest(
      () => _client.post<void>(
        '/v0/users/-/collections/$subjectId',
        data: _compactMap(<String, Object?>{
          'type': type,
          'rate': rate,
          'comment': comment?.trim(),
          'private': isPrivate,
          'tags': _normalizeTags(tags),
          'ep_status': epStatus,
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

  List<String>? _normalizeTags(List<String>? tags) {
    if (tags == null) {
      return null;
    }

    final normalized = tags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return normalized;
  }

  int? _normalizeSubjectType(int? subjectType) {
    if (subjectType == null) {
      return null;
    }

    if (!BangumiTypeMapper.supportedSubjectTypes.contains(subjectType)) {
      throw ArgumentError.value(
        subjectType,
        'subjectType',
        'Unsupported Bangumi subject type filter.',
      );
    }

    return subjectType;
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
