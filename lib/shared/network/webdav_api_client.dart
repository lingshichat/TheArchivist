import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/step_logger.dart';

sealed class WebDavApiException implements Exception {
  const WebDavApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => message;
}

final class WebDavNetworkError extends WebDavApiException {
  const WebDavNetworkError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class WebDavUnauthorizedError extends WebDavApiException {
  const WebDavUnauthorizedError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class WebDavNotFoundError extends WebDavApiException {
  const WebDavNotFoundError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class WebDavServerError extends WebDavApiException {
  const WebDavServerError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class WebDavUnknownError extends WebDavApiException {
  const WebDavUnknownError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

class WebDavAuth {
  const WebDavAuth({required this.username, required this.password});

  final String username;
  final String password;
}

class WebDavApiClient {
  WebDavApiClient({
    required Uri baseUri,
    Future<WebDavAuth?> Function()? authProvider,
    String? userAgent,
    Future<String> Function()? userAgentProvider,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    Dio? dio,
    StepLogger? logger,
  }) : baseUri = _normalizeBaseUri(baseUri),
       _authProvider = authProvider ?? alwaysNullAuthProvider,
       _userAgentProvider =
           userAgentProvider ??
           (userAgent == null ? defaultUserAgent : () async => userAgent),
       _logger = logger ?? const StepLogger('WebDavApiClient'),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: _normalizeBaseUri(baseUri).toString(),
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
               headers: const <String, Object?>{'Accept': '*/*'},
               responseType: ResponseType.plain,
             ),
           ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const String _contactUrl =
      'https://github.com/lingshi/record-anywhere';

  final Uri baseUri;
  final Dio _dio;
  final Future<WebDavAuth?> Function() _authProvider;
  final Future<String> Function() _userAgentProvider;
  final StepLogger _logger;

  Future<String>? _resolvedUserAgent;

  Dio get dio => _dio;

  static Future<WebDavAuth?> alwaysNullAuthProvider() async => null;

  static Future<String> defaultUserAgent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'record-anywhere/${packageInfo.version} ($_contactUrl)';
  }

  Future<Response<String>> propfind(
    String path, {
    String depth = '1',
    String? body,
  }) {
    /*
     * ========================================================================
     * 步骤1：发起 WebDAV PROPFIND 请求
     * ========================================================================
     * 目标：
     *   1) 读取目标目录下的资源元信息
     *   2) 保持 transport 层只返回原始响应，不掺业务语义
     */
    _logger.info('开始发起 WebDAV PROPFIND 请求...');

    // 1.1 统一补齐方法、Depth 头和 XML Content-Type
    final future = _dio.request<String>(
      _normalizeRelativePath(path),
      data: body,
      options: Options(
        method: 'PROPFIND',
        headers: <String, Object?>{
          'Depth': depth,
          'Content-Type': 'application/xml; charset=utf-8',
        },
      ),
    );
    _logger.info('WebDAV PROPFIND 请求已发起。');
    return future;
  }

  Future<Response<String>> getText(String path) {
    /*
     * ========================================================================
     * 步骤2：发起 WebDAV GET 请求
     * ========================================================================
     * 目标：
     *   1) 按相对路径读取文本资源
     *   2) 复用统一请求头和错误映射
     */
    _logger.info('开始发起 WebDAV GET 请求...');

    // 2.1 直接读取目标文本资源
    final future = _dio.get<String>(_normalizeRelativePath(path));
    _logger.info('WebDAV GET 请求已发起。');
    return future;
  }

  Future<Response<String>> putText(
    String path, {
    required String content,
    String contentType = 'application/json; charset=utf-8',
  }) {
    /*
     * ========================================================================
     * 步骤3：发起 WebDAV PUT 请求
     * ========================================================================
     * 目标：
     *   1) 写入 JSON 或其他文本内容
     *   2) 显式声明 Content-Type，避免服务端猜测
     */
    _logger.info('开始发起 WebDAV PUT 请求...');

    // 3.1 按统一相对路径写入文本内容
    final future = _dio.put<String>(
      _normalizeRelativePath(path),
      data: content,
      options: Options(headers: <String, Object?>{'Content-Type': contentType}),
    );
    _logger.info('WebDAV PUT 请求已发起。');
    return future;
  }

  Future<Response<String>> deleteResource(String path) {
    /*
     * ========================================================================
     * 步骤4：发起 WebDAV DELETE 请求
     * ========================================================================
     * 目标：
     *   1) 删除目标资源
     *   2) 保持删除语义只停留在 transport 层
     */
    _logger.info('开始发起 WebDAV DELETE 请求...');

    // 4.1 按统一相对路径删除资源
    final future = _dio.delete<String>(_normalizeRelativePath(path));
    _logger.info('WebDAV DELETE 请求已发起。');
    return future;
  }

  Future<Response<String>> createCollection(String path) {
    /*
     * ========================================================================
     * 步骤5：发起 WebDAV MKCOL 请求
     * ========================================================================
     * 目标：
     *   1) 创建目标目录
     *   2) 让上层按需逐级补目录
     */
    _logger.info('开始发起 WebDAV MKCOL 请求...');

    // 5.1 用 MKCOL 创建目录资源
    final future = _dio.request<String>(
      _normalizeRelativePath(path),
      options: Options(method: 'MKCOL'),
    );
    _logger.info('WebDAV MKCOL 请求已发起。');
    return future;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    /*
     * ========================================================================
     * 步骤6：补齐 WebDAV 请求头
     * ========================================================================
     * 目标：
     *   1) 统一写入 Accept 与 User-Agent
     *   2) 在需要时补 Basic Authorization
     */
    _logger.info('开始补齐 WebDAV 请求头...');

    options.headers['Accept'] = '*/*';
    options.headers['User-Agent'] = await _resolveUserAgent();

    final auth = await _authProvider();
    if (auth == null) {
      options.headers.remove(HttpHeaders.authorizationHeader);
    } else {
      final credentials = base64Encode(
        utf8.encode('${auth.username}:${auth.password}'),
      );
      options.headers[HttpHeaders.authorizationHeader] = 'Basic $credentials';
    }

    _logger.info('WebDAV 请求头补齐完成。');
    handler.next(options);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    _logger.info('开始映射 WebDAV 传输错误...');
    handler.reject(error.copyWith(error: toApiException(error)));
    _logger.info('WebDAV 传输错误映射完成。');
  }

  Future<String> _resolveUserAgent() {
    return _resolvedUserAgent ??= _userAgentProvider();
  }

  WebDavApiException toApiException(DioException error) {
    /*
     * ========================================================================
     * 步骤7：把 DioException 映射成 WebDAV typed error
     * ========================================================================
     * 目标：
     *   1) 把网络层原始异常统一收敛
     *   2) 让上层只处理稳定的 WebDavApiException
     */
    _logger.info('开始把 DioException 映射成 WebDAV typed error...');

    final sourceError = error.error;
    if (sourceError is WebDavApiException) {
      _logger.info('DioException 到 WebDAV typed error 映射完成。');
      return sourceError;
    }

    final responseBody = _serializeResponseBody(error.response?.data);
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final mapped = WebDavNetworkError(
          'WebDAV request failed because the network is unavailable.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
        _logger.info('DioException 到 WebDAV typed error 映射完成。');
        return mapped;
      case DioExceptionType.badResponse:
        final mapped = _mapBadResponse(
          statusCode: statusCode,
          responseBody: responseBody,
        );
        _logger.info('DioException 到 WebDAV typed error 映射完成。');
        return mapped;
      case DioExceptionType.cancel:
        final mapped = WebDavUnknownError(
          'WebDAV request was cancelled.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
        _logger.info('DioException 到 WebDAV typed error 映射完成。');
        return mapped;
      case DioExceptionType.badCertificate:
        final mapped = WebDavUnknownError(
          'WebDAV request failed certificate validation.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
        _logger.info('DioException 到 WebDAV typed error 映射完成。');
        return mapped;
      case DioExceptionType.unknown:
        if (sourceError is SocketException || sourceError is TimeoutException) {
          final mapped = WebDavNetworkError(
            'WebDAV request failed because the network is unavailable.',
            statusCode: statusCode,
            responseBody: responseBody,
          );
          _logger.info('DioException 到 WebDAV typed error 映射完成。');
          return mapped;
        }

        final mapped = WebDavUnknownError(
          'WebDAV request failed unexpectedly.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
        _logger.info('DioException 到 WebDAV typed error 映射完成。');
        return mapped;
    }
  }

  WebDavApiException _mapBadResponse({
    required int? statusCode,
    required String? responseBody,
  }) {
    if (statusCode == null) {
      return WebDavUnknownError(
        'WebDAV request failed without a status code.',
        responseBody: responseBody,
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      return WebDavUnauthorizedError(
        'WebDAV authentication is invalid or expired.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 404) {
      return WebDavNotFoundError(
        'WebDAV resource was not found.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 429 || statusCode >= 500) {
      return WebDavServerError(
        'WebDAV server is temporarily unavailable.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    return WebDavServerError(
      'WebDAV request was rejected by the server.',
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  static Uri _normalizeBaseUri(Uri input) {
    final normalizedPath = input.path.endsWith('/')
        ? input.path
        : '${input.path}/';
    return input.replace(path: normalizedPath);
  }

  static String _normalizeRelativePath(String path) {
    if (path.trim().isEmpty) {
      return '';
    }

    final normalizedSegments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return normalizedSegments.join('/');
  }

  static String? _serializeResponseBody(Object? data) {
    if (data == null) {
      return null;
    }

    if (data is String) {
      return data;
    }

    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
