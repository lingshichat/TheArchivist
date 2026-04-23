import 'dart:io';

import 'package:dio/dio.dart';

import '../../../shared/network/webdav_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_exception.dart';
import 'sync_storage_adapter.dart';

class WebDavStorageAdapterConfig {
  const WebDavStorageAdapterConfig({
    required this.baseUri,
    required this.username,
    required this.password,
    this.rootPath = '',
  });

  final Uri baseUri;
  final String username;
  final String password;
  final String rootPath;
}

class WebDavStorageAdapter implements SyncStorageAdapter {
  WebDavStorageAdapter({
    required WebDavApiClient client,
    required String rootPath,
    StepLogger? logger,
  }) : _client = client,
       _rootPath = _normalizeRootPath(rootPath),
       _logger = logger ?? const StepLogger('WebDavStorageAdapter');

  final WebDavApiClient _client;
  final String _rootPath;
  final StepLogger _logger;

  @override
  Future<void> delete(String key) async {
    /*
     * ========================================================================
     * 步骤1：删除远端 WebDAV 对象
     * ========================================================================
     * 目标：
     *   1) 删除实体或 tombstone 对象
     *   2) 把传输层错误统一映射成 SyncException
     */
    _logger.info('开始删除远端 WebDAV 对象...');

    try {
      // 1.1 直接按统一 key 定位远端资源并发起 DELETE
      await _client.deleteResource(_buildRemotePath(key));
      _logger.info('远端 WebDAV 对象删除完成。');
    } on DioException catch (error) {
      _logger.info('远端 WebDAV 对象删除失败。');
      throw _mapDioException(error);
    } on WebDavApiException catch (error) {
      _logger.info('远端 WebDAV 对象删除失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<List<SyncStorageRecordRef>> listRecords() async {
    /*
     * ========================================================================
     * 步骤2：列举远端 WebDAV 同步对象
     * ========================================================================
     * 目标：
     *   1) 扫描 entities/ 与 tombstones/ 目录下的 JSON 对象
     *   2) 转成统一 SyncStorageRecordRef 列表供 engine 拉取
     */
    _logger.info('开始列举远端 WebDAV 同步对象...');

    try {
      // 2.1 依次扫描两类根目录，并过滤出统一 key
      final entityRefs = await _listDirectory(
        prefix: 'entities',
        kind: SyncStorageRecordKind.entity,
      );
      final tombstoneRefs = await _listDirectory(
        prefix: 'tombstones',
        kind: SyncStorageRecordKind.tombstone,
      );
      _logger.info('远端 WebDAV 同步对象列举完成。');
      return <SyncStorageRecordRef>[...entityRefs, ...tombstoneRefs];
    } on SyncException {
      _logger.info('远端 WebDAV 同步对象列举失败。');
      rethrow;
    } on DioException catch (error) {
      _logger.info('远端 WebDAV 同步对象列举失败。');
      throw _mapDioException(error);
    } on WebDavApiException catch (error) {
      _logger.info('远端 WebDAV 同步对象列举失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<String> readText(String key) async {
    /*
     * ========================================================================
     * 步骤3：读取远端 WebDAV 文本对象
     * ========================================================================
     * 目标：
     *   1) 按统一 key 读取远端 JSON 文本
     *   2) 保持 adapter 只返回原始文本，不做领域解释
     */
    _logger.info('开始读取远端 WebDAV 文本对象...');

    try {
      // 3.1 直接 GET 目标对象，并把文本原样返回给 codec
      final response = await _client.getText(_buildRemotePath(key));
      _logger.info('远端 WebDAV 文本对象读取完成。');
      return response.data ?? '';
    } on DioException catch (error) {
      _logger.info('远端 WebDAV 文本对象读取失败。');
      throw _mapDioException(error);
    } on WebDavApiException catch (error) {
      _logger.info('远端 WebDAV 文本对象读取失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<void> writeText({required String key, required String content}) async {
    /*
     * ========================================================================
     * 步骤4：写入远端 WebDAV 实体对象
     * ========================================================================
     * 目标：
     *   1) 保证目标目录存在
     *   2) 把统一 JSON 文本写入实体对象路径
     */
    _logger.info('开始写入远端 WebDAV 实体对象...');

    try {
      // 4.1 先补目录，再 PUT 文本内容
      await _ensureParentCollections(key);
      await _client.putText(_buildRemotePath(key), content: content);
      _logger.info('远端 WebDAV 实体对象写入完成。');
    } on SyncException {
      _logger.info('远端 WebDAV 实体对象写入失败。');
      rethrow;
    } on DioException catch (error) {
      _logger.info('远端 WebDAV 实体对象写入失败。');
      throw _mapDioException(error);
    } on WebDavApiException catch (error) {
      _logger.info('远端 WebDAV 实体对象写入失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<void> writeTombstone({
    required String key,
    required String content,
  }) async {
    /*
     * ========================================================================
     * 步骤5：写入远端 WebDAV tombstone 对象
     * ========================================================================
     * 目标：
     *   1) 复用与实体相同的目录创建策略
     *   2) 把 tombstone JSON 写入统一 tombstones 路径
     */
    _logger.info('开始写入远端 WebDAV tombstone 对象...');

    try {
      // 5.1 先补目录，再 PUT tombstone 文本
      await _ensureParentCollections(key);
      await _client.putText(_buildRemotePath(key), content: content);
      _logger.info('远端 WebDAV tombstone 对象写入完成。');
    } on SyncException {
      _logger.info('远端 WebDAV tombstone 对象写入失败。');
      rethrow;
    } on DioException catch (error) {
      _logger.info('远端 WebDAV tombstone 对象写入失败。');
      throw _mapDioException(error);
    } on WebDavApiException catch (error) {
      _logger.info('远端 WebDAV tombstone 对象写入失败。');
      throw _mapApiException(error);
    }
  }

  Future<List<SyncStorageRecordRef>> _listDirectory({
    required String prefix,
    required SyncStorageRecordKind kind,
  }) async {
    try {
      final response = await _client.propfind(
        _buildRemoteDirectoryPath(prefix),
        depth: 'infinity',
      );
      final xml = response.data ?? '';

      if (xml.trim().isEmpty) {
        return const <SyncStorageRecordRef>[];
      }

      final responseMatches = RegExp(
        r'<(?:[A-Za-z0-9_-]+:)?response\b[^>]*>([\s\S]*?)</(?:[A-Za-z0-9_-]+:)?response>',
        caseSensitive: false,
      ).allMatches(xml);

      final results = <SyncStorageRecordRef>[];
      for (final responseMatch in responseMatches) {
        final responseXml = responseMatch.group(1);
        if (responseXml == null || responseXml.isEmpty) {
          continue;
        }

        final hrefMatch = RegExp(
          r'<(?:[A-Za-z0-9_-]+:)?href>([^<]+)</(?:[A-Za-z0-9_-]+:)?href>',
          caseSensitive: false,
        ).firstMatch(responseXml);
        final href = hrefMatch?.group(1);
        if (href == null || href.isEmpty) {
          continue;
        }

        final relativeKey = _tryExtractKeyFromHref(href);
        if (relativeKey == null || !relativeKey.endsWith('.json')) {
          continue;
        }

        final modifiedMatch = RegExp(
          r'<(?:[A-Za-z0-9_-]+:)?getlastmodified>([^<]+)</(?:[A-Za-z0-9_-]+:)?getlastmodified>',
          caseSensitive: false,
        ).firstMatch(responseXml);
        final rawModified = modifiedMatch?.group(1);
        final parsedModified = rawModified == null
            ? null
            : _tryParseHttpDate(rawModified);
        final updatedAt =
            parsedModified?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

        results.add(
          SyncStorageRecordRef(
            key: relativeKey,
            kind: kind,
            updatedAt: updatedAt,
          ),
        );
      }

      return results;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped is SyncRemoteNotFoundException) {
        return const <SyncStorageRecordRef>[];
      }
      throw mapped;
    } on WebDavApiException catch (error) {
      final mapped = _mapApiException(error);
      if (mapped is SyncRemoteNotFoundException) {
        return const <SyncStorageRecordRef>[];
      }
      throw mapped;
    }
  }

  Future<void> _ensureParentCollections(String key) async {
    final keySegments = key
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final rootSegments = _rootPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final segments = <String>[
      ...rootSegments,
      ...keySegments.take(keySegments.length - 1),
    ];
    if (segments.length <= 1) {
      return;
    }

    var currentPath = '';
    for (final segment in segments) {
      currentPath = currentPath.isEmpty ? segment : '$currentPath/$segment';
      try {
        await _client.createCollection(currentPath);
      } on DioException catch (error) {
        final mapped = _mapDioException(error);
        if (mapped is SyncServerException &&
            error.response?.statusCode == HttpStatus.methodNotAllowed) {
          continue;
        }
        if (mapped is SyncServerException &&
            error.response?.statusCode == HttpStatus.conflict) {
          continue;
        }
        rethrow;
      } on WebDavApiException catch (error) {
        final mapped = _mapApiException(error);
        if (mapped is SyncServerException &&
            (error.statusCode == HttpStatus.methodNotAllowed ||
                error.statusCode == HttpStatus.conflict)) {
          continue;
        }
        throw mapped;
      }
    }
  }

  String _buildRemotePath(String key) {
    final segments = <String>[
      ..._rootPath.split('/').where((segment) => segment.isNotEmpty),
      ...key.split('/').where((segment) => segment.isNotEmpty),
    ];
    return _encodePathSegments(segments);
  }

  String _buildRemoteDirectoryPath(String prefix) {
    final segments = <String>[
      ..._rootPath.split('/').where((segment) => segment.isNotEmpty),
      ...prefix.split('/').where((segment) => segment.isNotEmpty),
    ];
    return _encodePathSegments(segments);
  }

  String? _tryExtractKeyFromHref(String href) {
    final decodedHref = Uri.decodeFull(href);
    final decodedBasePath = Uri.decodeFull(_client.baseUri.path);
    final normalizedHrefPath = _normalizeHrefPath(decodedHref);
    final normalizedBasePath = _normalizeHrefPath(decodedBasePath);

    if (!normalizedHrefPath.startsWith(normalizedBasePath)) {
      return null;
    }

    var relative = normalizedHrefPath.substring(normalizedBasePath.length);
    if (_rootPath.isNotEmpty) {
      if (!relative.startsWith('$_rootPath/')) {
        return null;
      }
      relative = relative.substring(_rootPath.length + 1);
    }

    if (relative.isEmpty || relative.endsWith('/')) {
      return null;
    }

    return relative.split('/').where((segment) => segment.isNotEmpty).join('/');
  }

  String _normalizeHrefPath(String rawPath) {
    final noQuery = rawPath.split('?').first.split('#').first;
    return noQuery.startsWith('/') ? noQuery.substring(1) : noQuery;
  }

  SyncException _mapDioException(DioException error) {
    return _mapApiException(_client.toApiException(error));
  }

  SyncException _mapApiException(WebDavApiException error) {
    return switch (error) {
      WebDavNetworkError() => SyncNetworkException(error.message),
      WebDavUnauthorizedError() => SyncAuthException(error.message),
      WebDavNotFoundError() => SyncRemoteNotFoundException(error.message),
      WebDavServerError() => SyncServerException(error.message),
      WebDavUnknownError() => SyncServerException(error.message),
    };
  }

  static String _normalizeRootPath(String path) {
    return path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.decodeComponent)
        .join('/');
  }

  static String _encodePathSegments(Iterable<String> segments) {
    return segments.map(Uri.encodeComponent).join('/');
  }

  static DateTime? _tryParseHttpDate(String value) {
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }
}
