import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

sealed class BangumiApiException implements Exception {
  const BangumiApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => message;
}

final class BangumiNetworkError extends BangumiApiException {
  const BangumiNetworkError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class BangumiUnauthorizedError extends BangumiApiException {
  const BangumiUnauthorizedError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class BangumiNotFoundError extends BangumiApiException {
  const BangumiNotFoundError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class BangumiBadRequestError extends BangumiApiException {
  const BangumiBadRequestError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class BangumiServerError extends BangumiApiException {
  const BangumiServerError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class BangumiUnknownError extends BangumiApiException {
  const BangumiUnknownError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

class BangumiApiClient {
  BangumiApiClient({
    String baseUrl = defaultBaseUrl,
    Future<String?> Function()? tokenProvider,
    String? userAgent,
    Future<String> Function()? userAgentProvider,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    Dio? dio,
  }) : _tokenProvider = tokenProvider ?? alwaysNullTokenProvider,
       _userAgentProvider =
           userAgentProvider ??
           (userAgent == null ? defaultUserAgent : () async => userAgent),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
               headers: const <String, Object?>{'Accept': 'application/json'},
               responseType: ResponseType.json,
             ),
           ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const String defaultBaseUrl = 'https://api.bgm.tv';
  static const String _contactUrl =
      'https://github.com/lingshi/record-anywhere';

  final Dio _dio;
  final Future<String?> Function() _tokenProvider;
  final Future<String> Function() _userAgentProvider;

  Future<String>? _resolvedUserAgent;

  Dio get dio => _dio;

  static Future<String?> alwaysNullTokenProvider() async => null;

  static Future<String> defaultUserAgent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'record-anywhere/${packageInfo.version} ($_contactUrl)';
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = 'application/json';
    options.headers['User-Agent'] = await _resolveUserAgent();

    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      options.headers.remove(HttpHeaders.authorizationHeader);
    } else {
      options.headers[HttpHeaders.authorizationHeader] =
          'Bearer ${token.trim()}';
    }

    handler.next(options);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    handler.reject(error.copyWith(error: toApiException(error)));
  }

  Future<String> _resolveUserAgent() {
    return _resolvedUserAgent ??= _userAgentProvider();
  }

  BangumiApiException toApiException(DioException error) {
    final sourceError = error.error;
    if (sourceError is BangumiApiException) {
      return sourceError;
    }

    final responseBody = _serializeResponseBody(error.response?.data);
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return BangumiNetworkError(
          'Bangumi request failed because the network is unavailable.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badResponse:
        return _mapBadResponse(
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.cancel:
        return BangumiUnknownError(
          'Bangumi request was cancelled.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badCertificate:
        return BangumiUnknownError(
          'Bangumi request failed certificate validation.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.unknown:
        if (sourceError is SocketException || sourceError is TimeoutException) {
          return BangumiNetworkError(
            'Bangumi request failed because the network is unavailable.',
            statusCode: statusCode,
            responseBody: responseBody,
          );
        }

        return BangumiUnknownError(
          'Bangumi request failed unexpectedly.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
    }
  }

  BangumiApiException _mapBadResponse({
    required int? statusCode,
    required String? responseBody,
  }) {
    if (statusCode == null) {
      return BangumiUnknownError(
        'Bangumi request failed without a status code.',
        responseBody: responseBody,
      );
    }

    if (statusCode == 400 || statusCode == 412) {
      return BangumiBadRequestError(
        'Bangumi rejected the request as invalid.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      return BangumiUnauthorizedError(
        'Bangumi authentication is invalid or expired.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 404) {
      return BangumiNotFoundError(
        'Bangumi resource was not found.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 429 || statusCode >= 500) {
      return BangumiServerError(
        'Bangumi is temporarily unavailable.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    return BangumiUnknownError(
      'Bangumi request failed with status $statusCode.',
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  String? _serializeResponseBody(Object? body) {
    if (body == null) {
      return null;
    }

    if (body is String) {
      return body;
    }

    try {
      return jsonEncode(body);
    } catch (_) {
      return body.toString();
    }
  }
}
