class BangumiOAuthConfig {
  const BangumiOAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  factory BangumiOAuthConfig.fromEnvironment() {
    /*
     * ========================================================================
     * 步骤1：从运行时环境读取 Bangumi OAuth 配置
     * ========================================================================
     * 目标：
     *   1) 通过 `--dart-define` 注入 client_id / client_secret / redirect_uri
     *   2) 避免把 OAuth 凭据直接写进仓库源码
     */

    // 1.1 读取三个 OAuth 必需字段
    const clientId = String.fromEnvironment('BANGUMI_CLIENT_ID');
    const clientSecret = String.fromEnvironment('BANGUMI_CLIENT_SECRET');
    const redirectUri = String.fromEnvironment('BANGUMI_REDIRECT_URI');

    // 1.2 缺字段时返回空配置，由调用方决定是否启用 OAuth 登录按钮
    final normalizedClientId = _normalizeOptional(clientId);
    final normalizedClientSecret = _normalizeOptional(clientSecret);
    final normalizedRedirectUri = _normalizeOptional(redirectUri);
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
