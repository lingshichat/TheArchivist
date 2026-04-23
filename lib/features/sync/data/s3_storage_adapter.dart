import 'package:dio/dio.dart';

import '../../../shared/network/s3_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_exception.dart';
import 'sync_storage_adapter.dart';

class S3StorageAdapterConfig {
  const S3StorageAdapterConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.rootPrefix = '',
    this.sessionToken,
    this.addressingStyle = S3AddressingStyle.pathStyle,
  });

  final Uri endpoint;
  final String region;
  final String bucket;
  final String rootPrefix;
  final String accessKey;
  final String secretKey;
  final String? sessionToken;
  final S3AddressingStyle addressingStyle;
}

class S3StorageAdapter implements SyncStorageAdapter {
  S3StorageAdapter({
    required S3ApiClient client,
    String? rootPrefix,
    StepLogger? logger,
  }) : _client = client,
       _rootPrefix = _normalizeRootPrefix(
         rootPrefix ?? client.requestConfig.rootPrefix,
       ),
       _logger = logger ?? const StepLogger('S3StorageAdapter');

  final S3ApiClient _client;
  final String _rootPrefix;
  final StepLogger _logger;

  @override
  Future<void> delete(String key) async {
    /*
     * Delete is intentionally idempotent for storage adapters. S3-compatible
     * services normally return success for a missing object, but some
     * implementations return 404; both mean the remote object is gone.
     */
    _logger.info('开始删除远端 S3 对象...');

    try {
      await _client.deleteObject(_buildObjectKey(key));
      _logger.info('远端 S3 对象删除完成。');
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      if (mapped is SyncRemoteNotFoundException) {
        _logger.info('远端 S3 对象不存在，按幂等删除处理。');
        return;
      }
      _logger.info('远端 S3 对象删除失败。');
      throw mapped;
    } on S3ApiException catch (error) {
      final mapped = _mapApiException(error);
      if (mapped is SyncRemoteNotFoundException) {
        _logger.info('远端 S3 对象不存在，按幂等删除处理。');
        return;
      }
      _logger.info('远端 S3 对象删除失败。');
      throw mapped;
    }
  }

  @override
  Future<List<SyncStorageRecordRef>> listRecords() async {
    /*
     * The engine consumes logical sync keys only. This method hides S3
     * pagination and strips the configured root prefix from returned object
     * keys before building SyncStorageRecordRef values.
     */
    _logger.info('开始列举远端 S3 同步对象...');

    try {
      final entityRefs = await _listObjects(
        logicalPrefix: 'entities/',
        kind: SyncStorageRecordKind.entity,
      );
      final tombstoneRefs = await _listObjects(
        logicalPrefix: 'tombstones/',
        kind: SyncStorageRecordKind.tombstone,
      );
      _logger.info('远端 S3 同步对象列举完成。');
      return <SyncStorageRecordRef>[...entityRefs, ...tombstoneRefs];
    } on SyncException {
      _logger.info('远端 S3 同步对象列举失败。');
      rethrow;
    } on DioException catch (error) {
      _logger.info('远端 S3 同步对象列举失败。');
      throw _mapDioException(error);
    } on S3ApiException catch (error) {
      _logger.info('远端 S3 同步对象列举失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<String> readText(String key) async {
    _logger.info('开始读取远端 S3 文本对象...');

    try {
      final response = await _client.getText(_buildObjectKey(key));
      _logger.info('远端 S3 文本对象读取完成。');
      return response.data ?? '';
    } on DioException catch (error) {
      _logger.info('远端 S3 文本对象读取失败。');
      throw _mapDioException(error);
    } on S3ApiException catch (error) {
      _logger.info('远端 S3 文本对象读取失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<void> writeText({required String key, required String content}) async {
    _logger.info('开始写入远端 S3 实体对象...');

    try {
      await _client.putText(_buildObjectKey(key), content: content);
      _logger.info('远端 S3 实体对象写入完成。');
    } on DioException catch (error) {
      _logger.info('远端 S3 实体对象写入失败。');
      throw _mapDioException(error);
    } on S3ApiException catch (error) {
      _logger.info('远端 S3 实体对象写入失败。');
      throw _mapApiException(error);
    }
  }

  @override
  Future<void> writeTombstone({
    required String key,
    required String content,
  }) async {
    _logger.info('开始写入远端 S3 tombstone 对象...');

    try {
      await _client.putText(_buildObjectKey(key), content: content);
      _logger.info('远端 S3 tombstone 对象写入完成。');
    } on DioException catch (error) {
      _logger.info('远端 S3 tombstone 对象写入失败。');
      throw _mapDioException(error);
    } on S3ApiException catch (error) {
      _logger.info('远端 S3 tombstone 对象写入失败。');
      throw _mapApiException(error);
    }
  }

  Future<List<SyncStorageRecordRef>> _listObjects({
    required String logicalPrefix,
    required SyncStorageRecordKind kind,
  }) async {
    final results = <SyncStorageRecordRef>[];
    String? continuationToken;

    do {
      final response = await _client.listObjectsV2(
        prefix: _buildObjectPrefix(logicalPrefix),
        continuationToken: continuationToken,
      );
      final page = _parseListObjectsV2Page(
        response.data ?? '',
        logicalPrefix: logicalPrefix,
        kind: kind,
      );

      results.addAll(page.refs);

      if (page.isTruncated && page.nextContinuationToken == null) {
        throw const SyncFormatException(
          'S3 list response is truncated but missing NextContinuationToken.',
        );
      }

      continuationToken = page.isTruncated ? page.nextContinuationToken : null;
    } while (continuationToken != null);

    return results;
  }

  _S3ListObjectsPage _parseListObjectsV2Page(
    String xml, {
    required String logicalPrefix,
    required SyncStorageRecordKind kind,
  }) {
    if (xml.trim().isEmpty) {
      return const _S3ListObjectsPage(
        refs: <SyncStorageRecordRef>[],
        isTruncated: false,
      );
    }

    final refs = <SyncStorageRecordRef>[];
    final contentsMatches = RegExp(
      r'<(?:[A-Za-z0-9_-]+:)?Contents\b[^>]*>([\s\S]*?)</(?:[A-Za-z0-9_-]+:)?Contents>',
      caseSensitive: false,
    ).allMatches(xml);

    for (final contentsMatch in contentsMatches) {
      final contentsXml = contentsMatch.group(1);
      if (contentsXml == null || contentsXml.isEmpty) {
        continue;
      }

      final rawKey = _firstXmlElementText(contentsXml, 'Key');
      if (rawKey == null || rawKey.isEmpty) {
        continue;
      }

      final logicalKey = _tryExtractLogicalKey(
        rawKey,
        expectedPrefix: logicalPrefix,
      );
      if (logicalKey == null || !logicalKey.endsWith('.json')) {
        continue;
      }

      refs.add(
        SyncStorageRecordRef(
          key: logicalKey,
          kind: kind,
          updatedAt:
              _tryParseIsoDate(
                _firstXmlElementText(contentsXml, 'LastModified'),
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }

    final isTruncated = _parseS3Bool(_firstXmlElementText(xml, 'IsTruncated'));

    final nextContinuationToken = _firstXmlElementText(
      xml,
      'NextContinuationToken',
    );

    return _S3ListObjectsPage(
      refs: refs,
      isTruncated: isTruncated,
      nextContinuationToken:
          nextContinuationToken == null || nextContinuationToken.isEmpty
          ? null
          : nextContinuationToken,
    );
  }

  String _buildObjectKey(String key) {
    return _normalizeObjectKey(key);
  }

  String _buildObjectPrefix(String logicalPrefix) {
    final prefix = _normalizeObjectKey(logicalPrefix);
    if (prefix.isEmpty || prefix.endsWith('/')) {
      return prefix;
    }
    return '$prefix/';
  }

  String? _tryExtractLogicalKey(
    String objectKey, {
    required String expectedPrefix,
  }) {
    var normalized = _normalizeObjectKey(objectKey);
    if (_rootPrefix.isNotEmpty) {
      final rootPrefixWithSlash = '$_rootPrefix/';
      if (!normalized.startsWith(rootPrefixWithSlash)) {
        return null;
      }
      normalized = normalized.substring(rootPrefixWithSlash.length);
    }

    final normalizedExpectedPrefix = _normalizeObjectKey(expectedPrefix);
    if (!normalized.startsWith('$normalizedExpectedPrefix/')) {
      return null;
    }

    return normalized;
  }

  SyncException _mapDioException(DioException error) {
    return _mapApiException(_client.toApiException(error));
  }

  SyncException _mapApiException(S3ApiException error) {
    return switch (error) {
      S3NetworkError() => SyncNetworkException(error.message),
      S3UnauthorizedError() => SyncAuthException(error.message),
      S3NotFoundError() => SyncRemoteNotFoundException(error.message),
      S3ServerError() => SyncServerException(error.message),
      S3UnknownError() => SyncServerException(error.message),
    };
  }

  static String _normalizeRootPrefix(String prefix) {
    return _normalizeObjectKey(prefix);
  }

  static String _normalizeObjectKey(String key) {
    return key.split('/').where((segment) => segment.isNotEmpty).join('/');
  }

  static String? _firstXmlElementText(String xml, String tagName) {
    final match = RegExp(
      '<(?:[A-Za-z0-9_-]+:)?$tagName\\b[^>]*>([\\s\\S]*?)</(?:[A-Za-z0-9_-]+:)?$tagName>',
      caseSensitive: false,
    ).firstMatch(xml);
    final text = match?.group(1);
    if (text == null) {
      return null;
    }
    return _decodeXmlText(text.trim());
  }

  static bool _parseS3Bool(String? value) {
    return value?.toLowerCase() == 'true';
  }

  static DateTime? _tryParseIsoDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }

  static String _decodeXmlText(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }
}

class _S3ListObjectsPage {
  const _S3ListObjectsPage({
    required this.refs,
    required this.isTruncated,
    this.nextContinuationToken,
  });

  final List<SyncStorageRecordRef> refs;
  final bool isTruncated;
  final String? nextContinuationToken;
}
