import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

sealed class GitHubReleaseApiException implements Exception {
  const GitHubReleaseApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => message;
}

final class GitHubReleaseNetworkError extends GitHubReleaseApiException {
  const GitHubReleaseNetworkError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class GitHubReleaseNotFoundError extends GitHubReleaseApiException {
  const GitHubReleaseNotFoundError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class GitHubReleaseRateLimitedError extends GitHubReleaseApiException {
  const GitHubReleaseRateLimitedError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class GitHubReleaseServerError extends GitHubReleaseApiException {
  const GitHubReleaseServerError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

final class GitHubReleaseUnknownError extends GitHubReleaseApiException {
  const GitHubReleaseUnknownError(
    super.message, {
    super.statusCode,
    super.responseBody,
  });
}

class GitHubReleaseApiClient {
  GitHubReleaseApiClient({
    String owner = defaultOwner,
    String repo = defaultRepo,
    Future<String> Function()? userAgentProvider,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
    Dio? dio,
  })  : _userAgentProvider = userAgentProvider ?? defaultUserAgent,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.github.com/repos/$owner/$repo',
                connectTimeout: connectTimeout,
                receiveTimeout: receiveTimeout,
                headers: const <String, Object?>{
                  'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                },
                responseType: ResponseType.json,
              ),
            ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const String defaultOwner = 'lingshichat';
  static const String defaultRepo = 'TheArchivist';
  static const String _contactUrl =
      'https://github.com/lingshichat/TheArchivist';

  final Dio _dio;
  final Future<String> Function() _userAgentProvider;

  Future<String>? _resolvedUserAgent;

  Dio get dio => _dio;

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

  Future<void> download(
    String url,
    String savePath, {
    required ProgressCallback onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: const <String, Object?>{'Accept': 'application/octet-stream'},
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      options.headers['User-Agent'] = await _resolveUserAgent();
    } on Object {
      options.headers['User-Agent'] = 'record-anywhere/unknown ($_contactUrl)';
    }
    handler.next(options);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    handler.reject(error.copyWith(error: toApiException(error)));
  }

  Future<String> _resolveUserAgent() async {
    if (_resolvedUserAgent != null) {
      return _resolvedUserAgent!;
    }
    try {
      _resolvedUserAgent = _userAgentProvider();
      return await _resolvedUserAgent!;
    } on Object {
      _resolvedUserAgent = null;
      rethrow;
    }
  }

  GitHubReleaseApiException toApiException(DioException error) {
    final sourceError = error.error;
    if (sourceError is GitHubReleaseApiException) {
      return sourceError;
    }

    final responseBody = _serializeResponseBody(error.response?.data);
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return GitHubReleaseNetworkError(
          'Unable to reach GitHub Releases. Check your network connection.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badResponse:
        return _mapBadResponse(
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.cancel:
        return GitHubReleaseUnknownError(
          'The update request was cancelled.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.badCertificate:
        return GitHubReleaseUnknownError(
          'GitHub Releases failed certificate validation.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
      case DioExceptionType.unknown:
        if (sourceError is SocketException || sourceError is TimeoutException) {
          return GitHubReleaseNetworkError(
            'Unable to reach GitHub Releases. Check your network connection.',
            statusCode: statusCode,
            responseBody: responseBody,
          );
        }

        return GitHubReleaseUnknownError(
          'GitHub Releases failed unexpectedly.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
    }
  }

  GitHubReleaseApiException _mapBadResponse({
    required int? statusCode,
    required String? responseBody,
  }) {
    if (statusCode == 404) {
      return GitHubReleaseNotFoundError(
        'No GitHub Release was found for this application.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode == 403 || statusCode == 429) {
      return GitHubReleaseRateLimitedError(
        'GitHub Releases is rate limited. Try again later.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return GitHubReleaseServerError(
        'GitHub Releases is temporarily unavailable.',
        statusCode: statusCode,
        responseBody: responseBody,
      );
    }

    return GitHubReleaseUnknownError(
      statusCode == null
          ? 'GitHub Releases failed without a status code.'
          : 'GitHub Releases failed with status $statusCode.',
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
    } on JsonUnsupportedObjectError {
      return body.toString();
    }
  }
}
