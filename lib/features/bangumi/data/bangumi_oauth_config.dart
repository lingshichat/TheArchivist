import '../../../shared/utils/step_logger.dart';

class BangumiOAuthConfig {
  const BangumiOAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  static const StepLogger _logger = StepLogger('BangumiOAuthConfig');
  static const String _builtInClientId = 'bgm599869e73329cb7f3';
  static const String _builtInClientSecret = '2e8faa28bf192889707c1c0f681e701b';
  static const String _builtInRedirectUri = 'http://127.0.0.1:17863/callback';

  factory BangumiOAuthConfig.fromEnvironment() {
    /*
     * ========================================================================
     * 步骤1：解析 Bangumi OAuth 桌面端配置
     * ========================================================================
     * 目标：
     *   1) 优先读取 `--dart-define` 注入的 OAuth 配置
     *   2) 未注入时回退到桌面端内置配置，保证裸 `flutter run` 可登录
     */
    _logger.info('开始解析 Bangumi OAuth 桌面端配置...');

    // 1.1 读取三个可覆盖的 OAuth 编译期字段
    const environmentClientId = String.fromEnvironment('BANGUMI_CLIENT_ID');
    const environmentClientSecret = String.fromEnvironment(
      'BANGUMI_CLIENT_SECRET',
    );
    const environmentRedirectUri = String.fromEnvironment(
      'BANGUMI_REDIRECT_URI',
    );

    // 1.2 合并编译期覆盖值和内置桌面端默认值
    final normalizedClientId =
        _normalizeOptional(environmentClientId) ??
        _normalizeOptional(_builtInClientId);
    final normalizedClientSecret =
        _normalizeOptional(environmentClientSecret) ??
        _normalizeOptional(_builtInClientSecret);
    final normalizedRedirectUri =
        _normalizeOptional(environmentRedirectUri) ??
        _normalizeOptional(_builtInRedirectUri);
    if (normalizedClientId == null ||
        normalizedClientSecret == null ||
        normalizedRedirectUri == null) {
      throw const FormatException('Bangumi OAuth config is incomplete.');
    }

    // 1.3 校验 redirect_uri 基础格式，并输出稳定配置对象
    final parsedRedirectUri = Uri.tryParse(normalizedRedirectUri);
    if (parsedRedirectUri == null ||
        !parsedRedirectUri.hasScheme ||
        parsedRedirectUri.host.isEmpty) {
      throw const FormatException('Bangumi redirect_uri is invalid.');
    }

    _logger.info('Bangumi OAuth 桌面端配置解析完成。');

    return BangumiOAuthConfig(
      clientId: normalizedClientId,
      clientSecret: normalizedClientSecret,
      redirectUri: parsedRedirectUri,
    );
  }

  final String clientId;
  final String clientSecret;
  final Uri redirectUri;

  static BangumiOAuthConfig? tryFromEnvironment() {
    try {
      return BangumiOAuthConfig.fromEnvironment();
    } on FormatException {
      return null;
    }
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
