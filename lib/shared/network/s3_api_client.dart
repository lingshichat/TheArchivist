import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/step_logger.dart';

sealed class S3ApiException implements Exception {
  const S3ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => message;
}

final class S3NetworkError extends S3ApiException {
  const S3NetworkError(super.message, {super.statusCode, super.responseBody});
}

final class S3UnauthorizedError extends S3ApiException {
  const S3UnauthorizedError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class S3NotFoundError extends S3ApiException {
  const S3NotFoundError(super.message, {super.statusCode, super.responseBody});
}

final class S3ServerError extends S3ApiException {
  const S3ServerError(super.message, {super.statusCode, super.responseBody});
}

final class S3UnknownError extends S3ApiException {
  const S3UnknownError(super.message, {super.statusCode, super.responseBody});
}

enum S3AddressingStyle { pathStyle, virtualHostedStyle }

class S3Credentials {
  const S3Credentials({
    required this.accessKey,
    required this.secretKey,
    this.sessionToken,
  });

  final String accessKey;
  final String secretKey;
  final String? sessionToken;
}

class S3RequestConfig {
  const S3RequestConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    this.rootPrefix = '',
    this.addressingStyle = S3AddressingStyle.pathStyle,
  });

  final Uri endpoint;
  final String region;
  final String bucket;
  final String rootPrefix;
  final S3AddressingStyle addressingStyle;
}

class S3ApiClient {
  S3ApiClient({
    required S3RequestConfig requestConfig,
    required Future<S3Credentials> Function() credentialsProvider,
    String? userAgent,
    Future<String> Function()? userAgentProvider,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    Dio? dio,
    StepLogger? logger,
  }) : requestConfig = _normalizeRequestConfig(requestConfig),
       _credentialsProvider = credentialsProvider,
       _userAgentProvider =
           userAgentProvider ??
           (userAgent == null ? defaultUserAgent : () async => userAgent),
       _serviceConfiguration = S3ServiceConfiguration(),
       _logger = logger ?? const StepLogger('S3ApiClient'),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
               headers: const <String, Object?>{'Accept': '*/*'},
               responseType: ResponseType.plain,
             ),
           );

  static const String _contactUrl =
      'https://github.com/lingshi/record-anywhere';
  static const Set<String> _authErrorCodes = <String>{
    'AccessDenied',
    'AuthorizationHeaderMalformed',
    'ExpiredToken',
    'InvalidAccessKeyId',
    'InvalidSecurity',
    'RequestTimeTooSkewed',
    'SignatureDoesNotMatch',
    'TokenRefreshRequired',
  };
  static const Set<String> _notFoundErrorCodes = <String>{
    'NoSuchBucket',
    'NoSuchKey',
    'NotFound',
  };
  static final RegExp _xmlErrorCodePattern = RegExp(
    r'<(?:[A-Za-z0-9_-]+:)?Code>([^<]+)</(?:[A-Za-z0-9_-]+:)?Code>',
    caseSensitive: false,
  );

  final S3RequestConfig requestConfig;
  final Dio _dio;
  final Future<S3Credentials> Function() _credentialsProvider;
  final Future<String> Function() _userAgentProvider;
  final S3ServiceConfiguration _serviceConfiguration;
  final StepLogger _logger;

  Future<String>? _resolvedUserAgent;

  Dio get dio => _dio;

  static Future<String> defaultUserAgent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'record-anywhere/${packageInfo.version} ($_contactUrl)';
  }

  Future<Response<String>> listObjectsV2({
    required String prefix,
    String? continuationToken,
  }) {
    _logger.info('Starting S3 ListObjectsV2 request...');
    return _sendRequest(
      method: AWSHttpMethod.get,
      key: null,
      queryParameters: <String, Object>{
        'list-type': '2',
        if (_qualifyPrefix(prefix).isNotEmpty) 'prefix': _qualifyPrefix(prefix),
        if (continuationToken != null && continuationToken.isNotEmpty)
          'continuation-token': continuationToken,
      },
    );
  }

  Future<Response<String>> getText(String key) {
    _logger.info('Starting S3 GetObject request...');
    return _sendRequest(
      method: AWSHttpMethod.get,
      key: _normalizeObjectKey(key),
    );
  }

  Future<Response<String>> putText(
    String key, {
    required String content,
    String contentType = 'application/json; charset=utf-8',
  }) {
    _logger.info('Starting S3 PutObject request...');
    return _sendRequest(
      method: AWSHttpMethod.put,
      key: _normalizeObjectKey(key),
      bodyBytes: utf8.encode(content),
      contentType: contentType,
    );
  }

  Future<Response<String>> deleteObject(String key) {
    _logger.info('Starting S3 DeleteObject request...');
    return _sendRequest(
      method: AWSHttpMethod.delete,
      key: _normalizeObjectKey(key),
    );
  }

  Future<Response<String>> _sendRequest({
    required AWSHttpMethod method,
    required String? key,
    Map<String, Object>? queryParameters,
    List<int>? bodyBytes,
    String? contentType,
  }) async {
    try {
      final signedRequest = await _prepareSignedRequest(
        method: method,
        key: key,
        queryParameters: queryParameters,
        bodyBytes: bodyBytes ?? const <int>[],
        contentType: contentType,
      );
      final signedBodyBytes = signedRequest.bodyBytes;
      final requestData = signedBodyBytes.isEmpty
          ? null
          : _resolveRequestData(
              bodyBytes: signedBodyBytes,
              contentType: contentType,
            );
      final response = await _dio.requestUri<String>(
        signedRequest.uri,
        data: requestData,
        options: Options(
          method: method.value,
          headers: signedRequest.headers,
          responseType: ResponseType.plain,
        ),
      );
      _logger.info('S3 request completed.');
      return response;
    } on S3ApiException {
      _logger.info('S3 request failed.');
      rethrow;
    } on DioException catch (error) {
      _logger.info('S3 request failed.');
      throw toApiException(error);
    } on InvalidCredentialsException {
      _logger.info('S3 signing failed because credentials are invalid.');
      throw const S3UnauthorizedError(
        'S3 credentials are invalid or unavailable.',
      );
    } catch (_) {
      _logger.info('S3 request failed unexpectedly.');
      throw const S3UnknownError('S3 request failed unexpectedly.');
    }
  }

  Future<_SignedDioRequest> _prepareSignedRequest({
    required AWSHttpMethod method,
    required String? key,
    required Map<String, Object>? queryParameters,
    required List<int> bodyBytes,
    required String? contentType,
  }) async {
    final target = _buildRequestTarget(
      key: key == null ? null : _qualifyObjectKey(key),
      queryParameters: queryParameters,
    );
    final headers = <String, String>{
      'Accept': '*/*',
      AWSHeaders.platformUserAgent: await _resolveUserAgent(),
    };
    if (contentType != null) {
      headers[AWSHeaders.contentType] = contentType;
    }
    final credentials = await _resolveAwsCredentials();
    final signer = AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider(credentials),
    );
    final signedRequest = signer.signSync(
      AWSHttpRequest.raw(
        method: method,
        scheme: target.uri.scheme,
        host: target.uri.host,
        port: target.uri.hasPort ? target.uri.port : null,
        path: target.rawPath,
        queryParameters: target.queryParameters,
        headers: headers,
        body: bodyBytes,
      ),
      credentialScope: AWSCredentialScope(
        region: requestConfig.region,
        service: AWSService.s3,
      ),
      serviceConfiguration: _serviceConfiguration,
    );

    return _SignedDioRequest(
      uri: target.uri,
      headers: Map<String, Object?>.from(signedRequest.headers),
      bodyBytes: bodyBytes,
    );
  }

  Future<String> _resolveUserAgent() {
    return _resolvedUserAgent ??= _userAgentProvider();
  }

  Future<AWSCredentials> _resolveAwsCredentials() async {
    final credentials = await _credentialsProvider();
    final accessKey = credentials.accessKey.trim();
    final secretKey = credentials.secretKey.trim();
    final sessionToken = credentials.sessionToken?.trim();

    if (accessKey.isEmpty || secretKey.isEmpty) {
      throw const InvalidCredentialsException.couldNotLoad();
    }

    return AWSCredentials(
      accessKey,
      secretKey,
      sessionToken == null || sessionToken.isEmpty ? null : sessionToken,
    );
  }

  _S3RequestTarget _buildRequestTarget({
    required String? key,
    required Map<String, Object>? queryParameters,
  }) {
    final endpoint = requestConfig.endpoint;
    final host = switch (requestConfig.addressingStyle) {
      S3AddressingStyle.pathStyle => endpoint.host,
      S3AddressingStyle.virtualHostedStyle =>
        '${requestConfig.bucket}.${endpoint.host}',
    };
    final pathSegments = <String>[
      ...endpoint.pathSegments.where((segment) => segment.isNotEmpty),
      if (requestConfig.addressingStyle == S3AddressingStyle.pathStyle)
        requestConfig.bucket,
      if (key != null && key.isNotEmpty)
        ...key.split('/').where((segment) => segment.isNotEmpty),
    ];
    final stringQueryParameters = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    final uri =
        Uri(
          scheme: endpoint.scheme,
          host: host,
          port: endpoint.hasPort ? endpoint.port : null,
          pathSegments: pathSegments,
          queryParameters: stringQueryParameters?.isEmpty ?? true
              ? null
              : stringQueryParameters,
        ).replace(
          path: () {
            final path = Uri(pathSegments: pathSegments).path;
            return path.isEmpty ? '/' : path;
          }(),
        );

    return _S3RequestTarget(
      uri: uri,
      rawPath: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : Map<String, Object>.from(queryParameters),
    );
  }

  String _qualifyObjectKey(String key) {
    final normalizedKey = _normalizeObjectKey(key);
    if (requestConfig.rootPrefix.isEmpty) {
      return normalizedKey;
    }
    if (normalizedKey.isEmpty) {
      return requestConfig.rootPrefix;
    }
    return '${requestConfig.rootPrefix}/$normalizedKey';
  }

  String _qualifyPrefix(String prefix) {
    final normalizedPrefix = _normalizePrefix(prefix);
    if (requestConfig.rootPrefix.isEmpty) {
      return normalizedPrefix;
    }
    if (normalizedPrefix.isEmpty) {
      return '${requestConfig.rootPrefix}/';
    }
    return '${requestConfig.rootPrefix}/$normalizedPrefix';
  }

  S3ApiException toApiException(DioException error) {
    final sourceError = error.error;
    if (sourceError is S3ApiException) {
      return sourceError;
    }

    final responseBody = _serializeResponseBody(error.response?.data);
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return S3NetworkError(
          'S3 request failed because the network is unavailable.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badResponse:
        return _mapBadResponse(
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.cancel:
        return S3UnknownError(
          'S3 request was cancelled.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badCertificate:
        return S3UnknownError(
          'S3 request failed certificate validation.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.unknown:
        if (sourceError is SocketException || sourceError is TimeoutException) {
          return S3NetworkError(
            'S3 request failed because the network is unavailable.',
            statusCode: statusCode,
            responseBody: responseBody,
          );
        }
        return S3UnknownError(
          'S3 request failed unexpectedly.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
    }
  }

  S3ApiException _mapBadResponse({
    required int? statusCode,
    required String? responseBody,
  }) {
    final errorCode = _extractErrorCode(responseBody);

    if (errorCode != null && _notFoundErrorCodes.contains(errorCode)) {
      return S3NotFoundError(
        'S3 object was not found.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (errorCode != null && _authErrorCodes.contains(errorCode)) {
      return S3UnauthorizedError(
        'S3 authentication is invalid or expired.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == null) {
      return S3UnknownError(
        'S3 request failed without a status code.',
        responseBody: responseBody,
      );
    }

    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return S3UnauthorizedError(
        'S3 authentication is invalid or expired.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == HttpStatus.notFound) {
      return S3NotFoundError(
        'S3 object was not found.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == HttpStatus.tooManyRequests || statusCode >= 500) {
      return S3ServerError(
        'S3 server is temporarily unavailable.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    return S3ServerError(
      'S3 request was rejected by the server.',
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  static S3RequestConfig _normalizeRequestConfig(S3RequestConfig config) {
    final normalizedPathSegments = config.endpoint.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return S3RequestConfig(
      endpoint: config.endpoint.replace(
        pathSegments: normalizedPathSegments,
        query: null,
        fragment: null,
      ),
      region: config.region.trim(),
      bucket: config.bucket.trim(),
      rootPrefix: _normalizeRootPrefix(config.rootPrefix),
      addressingStyle: config.addressingStyle,
    );
  }

  static String _normalizeRootPrefix(String prefix) {
    return prefix
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .join('/');
  }

  static String _normalizeObjectKey(String key) {
    return key
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .join('/');
  }

  static String _normalizePrefix(String prefix) {
    final trimmed = prefix.trim();
    final normalized = trimmed
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .join('/');
    if (normalized.isEmpty) {
      return '';
    }
    return trimmed.endsWith('/') ? '$normalized/' : normalized;
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

  static String? _extractErrorCode(String? responseBody) {
    if (responseBody == null || responseBody.isEmpty) {
      return null;
    }
    return _xmlErrorCodePattern.firstMatch(responseBody)?.group(1)?.trim();
  }

  static Object? _resolveRequestData({
    required List<int> bodyBytes,
    required String? contentType,
  }) {
    if (bodyBytes.isEmpty) {
      return null;
    }

    final normalizedContentType = contentType?.toLowerCase();
    if (normalizedContentType == null) {
      return bodyBytes;
    }

    if (normalizedContentType.startsWith('application/json') ||
        normalizedContentType.startsWith('text/')) {
      return utf8.decode(bodyBytes);
    }

    return bodyBytes;
  }
}

class _S3RequestTarget {
  const _S3RequestTarget({
    required this.uri,
    required this.rawPath,
    required this.queryParameters,
  });

  final Uri uri;
  final String rawPath;
  final Map<String, Object>? queryParameters;
}

class _SignedDioRequest {
  const _SignedDioRequest({
    required this.uri,
    required this.headers,
    required this.bodyBytes,
  });

  final Uri uri;
  final Map<String, Object?> headers;
  final List<int> bodyBytes;
}
