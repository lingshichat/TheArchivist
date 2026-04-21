import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_api_service.dart';
import 'bangumi_auth.dart';

abstract class BangumiAuthVerifier {
  Future<BangumiAuth> verifyToken(String token);
}

class BangumiApiAuthVerifier implements BangumiAuthVerifier {
  BangumiApiAuthVerifier({
    required Future<String> Function() userAgentProvider,
    BangumiApiService Function(BangumiApiClient client)? serviceFactory,
    StepLogger? logger,
  }) : _userAgentProvider = userAgentProvider,
       _serviceFactory = serviceFactory ?? BangumiApiService.new,
       _logger = logger ?? const StepLogger('BangumiApiAuthVerifier');

  final Future<String> Function() _userAgentProvider;
  final BangumiApiService Function(BangumiApiClient client) _serviceFactory;
  final StepLogger _logger;

  @override
  Future<BangumiAuth> verifyToken(String token) async {
    /*
     * ========================================================================
     * 步骤1：使用候选 Access Token 验证 Bangumi 账号
     * ========================================================================
     * 目标：
     *   1) 只在远端验证成功后才允许上层持久化 token
     *   2) 复用现有 ApiClient / ApiService 分层，不让 UI 直接碰网络细节
     */
    _logger.info('开始验证 Bangumi Access Token...');

    // 1.1 归一化待验证 token，并拒绝空值输入
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Bangumi token cannot be empty.',
      );
    }

    // 1.2 使用候选 token 构造一次性认证 client，并请求当前用户信息
    final apiService = _serviceFactory(
      BangumiApiClient(
        tokenProvider: () async => normalizedToken,
        userAgentProvider: _userAgentProvider,
      ),
    );
    final user = await apiService.getMe();

    _logger.info('Bangumi Access Token 验证完成。');

    // 1.3 将远端用户 DTO 折叠成应用认证摘要
    return BangumiAuth.fromUser(user);
  }
}
