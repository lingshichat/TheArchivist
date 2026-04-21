import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/utils/step_logger.dart';
import 'bangumi_oauth_config.dart';

sealed class BangumiOAuthException implements Exception {
  const BangumiOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class BangumiOAuthUnavailableError extends BangumiOAuthException {
  const BangumiOAuthUnavailableError(super.message);
}

final class BangumiOAuthLaunchError extends BangumiOAuthException {
  const BangumiOAuthLaunchError(super.message);
}

final class BangumiOAuthCancelledError extends BangumiOAuthException {
  const BangumiOAuthCancelledError(super.message);
}

final class BangumiOAuthCallbackError extends BangumiOAuthException {
  const BangumiOAuthCallbackError(super.message);
}

final class BangumiOAuthTokenExchangeError extends BangumiOAuthException {
  const BangumiOAuthTokenExchangeError(super.message);
}

class BangumiOAuthTokenResponse {
  const BangumiOAuthTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
  });

  factory BangumiOAuthTokenResponse.fromJson(Map<String, Object?> json) {
    return BangumiOAuthTokenResponse(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: _normalizeOptional(json['refresh_token']?.toString()),
      tokenType: _normalizeOptional(json['token_type']?.toString()),
      expiresIn: _asInt(json['expires_in']),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

abstract class BangumiOAuthService {
  Future<String> authorize();
}

class BangumiBrowserOAuthService implements BangumiOAuthService {
  BangumiBrowserOAuthService({
    required BangumiOAuthConfig config,
    required Future<bool> Function(Uri uri) launchExternalUrl,
    Dio? dio,
    Uuid? uuid,
    StepLogger? logger,
  }) : _config = config,
       _launchExternalUrl = launchExternalUrl,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: 'https://bgm.tv',
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
               headers: const <String, Object?>{
                 'Accept': 'application/json',
                 'Content-Type': 'application/x-www-form-urlencoded',
               },
             ),
           ),
       _uuid = uuid ?? const Uuid(),
       _logger = logger ?? const StepLogger('BangumiBrowserOAuthService');

  final BangumiOAuthConfig _config;
  final Future<bool> Function(Uri uri) _launchExternalUrl;
  final Dio _dio;
  final Uuid _uuid;
  final StepLogger _logger;

  @override
  Future<String> authorize() async {
    /*
     * ========================================================================
     * 步骤1：拉起浏览器并等待 Bangumi OAuth 回调
     * ========================================================================
     * 目标：
     *   1) 用系统浏览器完成 Bangumi 授权，而不是要求手填 access token
     *   2) 通过本地 localhost 回调地址拿到授权 code
     */
    _logger.info('开始 Bangumi OAuth 浏览器授权流程...');

    // 1.1 校验 redirect_uri，确保当前配置是 localhost 回调
    _validateRedirectUri(_config.redirectUri);

    final server = await HttpServer.bind(
      _config.redirectUri.host,
      _config.redirectUri.port,
    );
    final state = _uuid.v4();
    final codeCompleter = Completer<String>();

    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      await _handleCallbackRequest(
        request,
        expectedState: state,
        codeCompleter: codeCompleter,
      );
    });

    try {
      final authorizeUri = _buildAuthorizeUri(state);
      final launched = await _launchExternalUrl(authorizeUri);
      if (!launched) {
        throw const BangumiOAuthLaunchError(
          'Could not open the browser for Bangumi login.',
        );
      }

      final code = await codeCompleter.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw const BangumiOAuthCancelledError(
            'Bangumi login timed out before the callback arrived.',
          );
        },
      );

      _logger.info('Bangumi OAuth 浏览器授权流程完成。');

      /*
       * ======================================================================
       * 步骤2：用授权 code 换取 Access Token
       * ======================================================================
       * 目标：
       *   1) 按 Bangumi OAuth 文档调用 access_token 端点
       *   2) 返回可供现有认证链路复用的 access token
       */
      _logger.info('开始用 Bangumi 授权 code 换取 Access Token...');

      final tokenResponse = await _exchangeCode(code);

      _logger.info('Bangumi Access Token 换取完成。');
      return tokenResponse.accessToken;
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Uri _buildAuthorizeUri(String state) {
    return Uri.https('bgm.tv', '/oauth/authorize', <String, String>{
      'client_id': _config.clientId,
      'response_type': 'code',
      'redirect_uri': _config.redirectUri.toString(),
      'state': state,
    });
  }

  Future<void> _handleCallbackRequest(
    HttpRequest request, {
    required String expectedState,
    required Completer<String> codeCompleter,
  }) async {
    /*
     * ========================================================================
     * 步骤3：处理本地 OAuth 回调请求
     * ========================================================================
     * 目标：
     *   1) 校验 state 和回调 path，防止错误请求混入
     *   2) 把授权结果安全返回给桌面端主流程
     */

    // 3.1 只接受配置中的回调 path，其余请求直接 404
    if (request.uri.path != _config.redirectUri.path) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final callbackState = request.uri.queryParameters['state'];
    final code = request.uri.queryParameters['code'];
    final error = request.uri.queryParameters['error'];

    if (error != null) {
      if (!codeCompleter.isCompleted) {
        codeCompleter.completeError(
          BangumiOAuthCallbackError(
            'Bangumi login was denied or failed: $error.',
          ),
        );
      }
      await _writeHtmlResponse(
        request.response,
        title: 'Bangumi Login Failed',
        body: 'Bangumi did not grant access. You can close this window.',
      );
      return;
    }

    if (callbackState != expectedState) {
      if (!codeCompleter.isCompleted) {
        codeCompleter.completeError(
          const BangumiOAuthCallbackError(
            'Bangumi login callback state did not match.',
          ),
        );
      }
      await _writeHtmlResponse(
        request.response,
        title: 'Bangumi Login Failed',
        body: 'The callback state did not match. You can close this window.',
      );
      return;
    }

    if (code == null || code.trim().isEmpty) {
      if (!codeCompleter.isCompleted) {
        codeCompleter.completeError(
          const BangumiOAuthCallbackError(
            'Bangumi login callback did not contain a code.',
          ),
        );
      }
      await _writeHtmlResponse(
        request.response,
        title: 'Bangumi Login Failed',
        body: 'The callback did not contain a code. You can close this window.',
      );
      return;
    }

    if (!codeCompleter.isCompleted) {
      codeCompleter.complete(code.trim());
    }

    await _writeHtmlResponse(
      request.response,
      title: 'Bangumi Login Complete',
      body: 'You can close this window and return to Record Anywhere.',
    );
  }

  Future<void> _writeHtmlResponse(
    HttpResponse response, {
    required String title,
    required String body,
  }) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write('''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>$title</title>
  </head>
  <body style="font-family: Segoe UI, Arial, sans-serif; padding: 24px; color: #2d3338;">
    <h2>$title</h2>
    <p>$body</p>
  </body>
</html>
''');
    await response.close();
  }

  Future<BangumiOAuthTokenResponse> _exchangeCode(String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/oauth/access_token',
        data: <String, String>{
          'grant_type': 'authorization_code',
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
          'code': code,
          'redirect_uri': _config.redirectUri.toString(),
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final body = Map<String, Object?>.from(
        response.data ?? const <String, Object?>{},
      );
      final tokenResponse = BangumiOAuthTokenResponse.fromJson(body);
      if (tokenResponse.accessToken.trim().isEmpty) {
        throw const BangumiOAuthTokenExchangeError(
          'Bangumi access_token response did not contain an access token.',
        );
      }

      return tokenResponse;
    } on DioException catch (error) {
      throw BangumiOAuthTokenExchangeError(
        'Could not exchange the Bangumi authorization code for a token: ${_serializeDioError(error)}',
      );
    }
  }

  void _validateRedirectUri(Uri redirectUri) {
    if (redirectUri.scheme != 'http' ||
        (redirectUri.host != '127.0.0.1' && redirectUri.host != 'localhost') ||
        redirectUri.port <= 0 ||
        redirectUri.path.isEmpty) {
      throw const BangumiOAuthUnavailableError(
        'Bangumi OAuth requires a localhost HTTP redirect_uri.',
      );
    }
  }

  String _serializeDioError(DioException error) {
    final body = error.response?.data;
    if (body == null) {
      return error.message ?? 'unknown Dio error';
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
