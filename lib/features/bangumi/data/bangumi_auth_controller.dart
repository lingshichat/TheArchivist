import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_auth.dart';
import 'bangumi_auth_verifier.dart';
import 'bangumi_sync_status.dart';
import 'bangumi_token_store.dart';
import 'providers.dart';

class BangumiAuthController extends AsyncNotifier<BangumiAuth?> {
  static const StepLogger _logger = StepLogger('BangumiAuthController');

  late final BangumiTokenStore _tokenStore;
  late final BangumiAuthVerifier _authVerifier;

  @override
  Future<BangumiAuth?> build() async {
    /*
     * ========================================================================
     * 步骤1：恢复本地 Bangumi 认证状态
     * ========================================================================
     * 目标：
     *   1) 应用启动后自动读取并校验已保存 token
     *   2) 遇到失效 token 时自动清理，避免脏状态残留
     */
    _logger.info('开始恢复本地 Bangumi 认证状态...');

    // 1.1 读取依赖，供后续 connect / disconnect 复用
    _tokenStore = ref.watch(bangumiTokenStoreProvider);
    _authVerifier = ref.watch(bangumiAuthVerifierProvider);

    // 1.2 读取本地 token；不存在时直接返回未连接态
    final storedToken = await _tokenStore.read();
    if (storedToken == null) {
      _logger.info('本地 Bangumi 认证状态恢复完成。');
      return null;
    }

    try {
      // 1.3 用已保存 token 拉取当前用户信息，恢复为已连接态
      final auth = await _authVerifier.verifyToken(storedToken);
      unawaited(
        _triggerBackgroundPull(
          auth,
          trigger: BangumiSyncTrigger.startupRestore,
        ),
      );
      _logger.info('本地 Bangumi 认证状态恢复完成。');
      return auth;
    } on BangumiUnauthorizedError catch (_) {
      // 1.4 token 失效时立即清理本地凭据，回到未连接态
      await _tokenStore.clear();
      _logger.info('本地 Bangumi 认证状态恢复完成。');
      return null;
    } on BangumiBadRequestError catch (_) {
      await _tokenStore.clear();
      _logger.info('本地 Bangumi 认证状态恢复完成。');
      return null;
    }
  }

  Future<void> connect(String token) async {
    /*
     * ========================================================================
     * 步骤2：验证并建立 Bangumi 连接
     * ========================================================================
     * 目标：
     *   1) 先验证候选 token，再决定是否持久化
     *   2) 保持 provider 状态、secure storage 与 UI 展示一致
     */
    _logger.info('开始建立 Bangumi 连接...');

    // 2.1 记录当前已连接状态，失败时用于回滚 UI 状态
    final previousAuth = state.valueOrNull;
    state = const AsyncLoading();

    try {
      // 2.2 先校验候选 token，验证成功后再写入本地存储
      final auth = await _authVerifier.verifyToken(token);
      await _tokenStore.write(token);
      state = AsyncData(auth);
      unawaited(
        _triggerBackgroundPull(auth, trigger: BangumiSyncTrigger.postConnect),
      );
      _logger.info('Bangumi 连接建立完成。');
    } catch (error, stackTrace) {
      // 2.3 失败时恢复上一份稳定状态，并继续把错误抛给 UI
      state = previousAuth == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previousAuth);
      _logger.info('Bangumi 连接建立失败。');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    /*
     * ========================================================================
     * 步骤3：断开 Bangumi 连接
     * ========================================================================
     * 目标：
     *   1) 删除本地 token 并同步清空认证状态
     *   2) 保证设置页与网络层后续都进入未连接态
     */
    _logger.info('开始断开 Bangumi 连接...');

    // 3.1 记录断开前状态，异常时回退 UI 展示
    final previousAuth = state.valueOrNull;
    state = const AsyncLoading();

    try {
      // 3.2 删除本地 token，并把 provider 状态切回 null
      await _tokenStore.clear();
      state = const AsyncData(null);
      _logger.info('Bangumi 连接断开完成。');
    } catch (error, stackTrace) {
      state = AsyncData(previousAuth);
      _logger.info('Bangumi 连接断开失败。');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> invalidateSession() async {
    /*
     * ========================================================================
     * 步骤4：失效化 Bangumi 会话
     * ========================================================================
     * 目标：
     *   1) 在同步返回 401/403 时统一清理本地认证状态
     *   2) 避免继续携带失效 token 发起后续请求
     */
    _logger.info('开始失效化 Bangumi 会话...');

    // 4.1 清除本地 token，并把 provider 状态重置为未连接
    await _tokenStore.clear();
    state = const AsyncData(null);

    _logger.info('Bangumi 会话失效化完成。');
  }

  Future<void> _triggerBackgroundPull(
    BangumiAuth auth, {
    required BangumiSyncTrigger trigger,
  }) async {
    /*
     * ========================================================================
     * 步骤5：在认证成功后触发后台收藏回拉
     * ========================================================================
     * 目标：
     *   1) 让首次连接和启动恢复都能自动把 Bangumi 收藏贴回本地
     *   2) 不阻塞认证 provider 进入已连接状态
     */
    _logger.info('开始触发认证后的后台收藏回拉...');

    // 5.1 交给同步状态控制器后台执行 pull；授权失效时仍由 auth 自己收口
    await ref
        .read(bangumiSyncStatusProvider.notifier)
        .runPull(
          username: auth.username,
          trigger: trigger,
          onUnauthorized: invalidateSession,
        );

    _logger.info('认证后的后台收藏回拉触发完成。');
  }
}
