import '../../../shared/data/app_database.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/user_entry_repository.dart';
import '../../../shared/data/source_id_map.dart';
import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_api_service.dart';
import 'bangumi_sync_feedback.dart';
import 'bangumi_token_store.dart';
import 'bangumi_type_mapper.dart';

abstract class BangumiSyncService {
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  });
}

class BangumiCollectionSyncService implements BangumiSyncService {
  BangumiCollectionSyncService({
    required BangumiApiService apiService,
    required MediaRepository mediaRepository,
    required UserEntryRepository userEntryRepository,
    required BangumiTokenStore tokenStore,
    required BangumiSyncFeedbackController feedbackController,
    required Future<void> Function() onUnauthorized,
    StepLogger? logger,
  }) : _apiService = apiService,
       _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _tokenStore = tokenStore,
       _feedbackController = feedbackController,
       _onUnauthorized = onUnauthorized,
       _logger = logger ?? const StepLogger('BangumiCollectionSyncService');

  final BangumiApiService _apiService;
  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final BangumiTokenStore _tokenStore;
  final BangumiSyncFeedbackController _feedbackController;
  final Future<void> Function() _onUnauthorized;
  final StepLogger _logger;

  @override
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  }) async {
    /*
     * ========================================================================
     * 步骤1：校验 Bangumi 推送前置条件
     * ========================================================================
     * 目标：
     *   1) 只在已绑定且存在 bangumi sourceId 时触发远端调用
     *   2) 继续保持“调用方不分支，服务内部静默跳过”的合同
     */
    _logger.info('开始校验 Bangumi 推送前置条件...');

    // 1.1 无待推送字段时直接结束，避免无意义请求
    if (status == null && score == null) {
      _logger.info('Bangumi 推送前置条件校验完成。');
      return;
    }

    // 1.2 无本地 token 时视为未绑定，直接静默跳过
    final token = await _tokenStore.read();
    if (token == null) {
      _logger.info('Bangumi 推送前置条件校验完成。');
      return;
    }

    // 1.3 读取本地条目并提取 bangumi subject id
    final mediaItem = await _mediaRepository.getItem(mediaItemId);
    final bangumiId = int.tryParse(
      SourceIdMap.get(mediaItem?.sourceIdsJson, 'bangumi') ?? '',
    );
    if (mediaItem == null || bangumiId == null) {
      _logger.info('Bangumi 推送前置条件校验完成。');
      return;
    }

    _logger.info('Bangumi 推送前置条件校验完成。');

    /*
     * ========================================================================
     * 步骤2：按字段变化执行 Bangumi 收藏同步
     * ========================================================================
     * 目标：
     *   1) 状态变化走 updateCollection，评分单独变化走 patchCollection
     *   2) 保持本地状态已经落库，远端只作为后置 side effect
     */
    _logger.info('开始执行 Bangumi 收藏同步...');

    try {
      // 2.1 状态变化时同步收藏类型；若同时带评分，则一并推送
      if (status != null) {
        await _apiService.updateCollection(
          bangumiId,
          type: BangumiTypeMapper.toCollectionType(status),
          rate: score,
        );
      } else {
        // 2.2 仅评分变化时只 patch rate，避免额外猜测远端收藏类型
        await _apiService.patchCollection(bangumiId, <String, Object?>{
          'rate': score,
        });
      }

      /*
       * ======================================================================
       * 步骤3：补写本地同步戳
       * ======================================================================
       * 目标：
       *   1) 让 push 成功后的本地条目具备稳定的 lastSyncedAt
       *   2) 供后续 pull 冲突判定识别“本地已与远端对齐”
       */
      _logger.info('开始补写 Bangumi 推送成功后的本地同步戳...');

      // 3.1 同步标记 media item 与 user entry，保持 local-first 冲突判定可用
      final syncedAt = DateTime.now();
      await _mediaRepository.markSynced(mediaItemId, syncedAt);
      await _userEntryRepository.markSynced(mediaItemId, syncedAt);

      _logger.info('Bangumi 推送成功后的本地同步戳补写完成。');
      _logger.info('Bangumi 收藏同步完成。');

      /*
       * ======================================================================
       * 步骤4：发布同步成功轻反馈
       * ======================================================================
       * 目标：
       *   1) 在本地保存反馈之后补充远端成功状态
       *   2) 不把 BuildContext 泄漏到 service 层
       */

      // 3.1 发布全局成功提示事件，交给 app-level listener 展示
      _feedbackController.publishSuccess('Synced to Bangumi.');
    } on BangumiUnauthorizedError catch (_) {
      /*
       * ======================================================================
       * 步骤5：处理授权失效
       * ======================================================================
       * 目标：
       *   1) 统一清理失效 token，避免后续重复发 401/403
       *   2) 仅做轻反馈，不回滚本地已保存状态
       */
      _logger.info('Bangumi 收藏同步失败，授权已失效。');

      // 4.1 清理本地认证状态，并提示用户去设置页重连
      await _onUnauthorized();
      _feedbackController.publishFailure(
        'Bangumi connection expired. Reconnect in Settings.',
      );
    } on BangumiApiException catch (error) {
      /*
       * ======================================================================
       * 步骤6：处理一般同步失败
       * ======================================================================
       * 目标：
       *   1) 把远端失败降级为轻反馈，不影响本地主流程
       *   2) 对不同错误类型输出稳定的用户提示
       */
      _logger.info('Bangumi 收藏同步失败。');

      // 5.1 根据 typed error 生成用户可读的失败提示
      _feedbackController.publishFailure(_messageForError(error));
    }
  }

  String _messageForError(BangumiApiException error) {
    switch (error) {
      case BangumiNetworkError():
        return 'Saved locally. Bangumi sync failed because the network is unavailable.';
      case BangumiBadRequestError():
        return 'Saved locally. Bangumi rejected the sync request.';
      case BangumiNotFoundError():
        return 'Saved locally. This Bangumi item could not be found remotely.';
      case BangumiServerError():
        return 'Saved locally. Bangumi is temporarily unavailable.';
      case BangumiUnknownError():
        return 'Saved locally. Bangumi sync failed unexpectedly.';
      case BangumiUnauthorizedError():
        return 'Bangumi connection expired. Reconnect in Settings.';
    }
  }
}

class NoopBangumiSyncService implements BangumiSyncService {
  NoopBangumiSyncService({StepLogger? logger})
    : _logger = logger ?? const StepLogger('NoopBangumiSyncService');

  final StepLogger _logger;

  @override
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  }) async {
    /*
     * ========================================================================
     * 步骤1：静默跳过未接入的 Bangumi 同步
     * ========================================================================
     * 目标：
     *   1) 满足测试或临时覆写场景下的同步接口合同
     *   2) 保持调用方可以继续无条件触发 pushCollection
     */
    _logger.info('开始跳过 Bangumi 同步占位实现...');

    // 1.1 当前实现不做远程调用，只保留接口兼容
    final _ = (mediaItemId, status, score);

    _logger.info('跳过 Bangumi 同步占位实现完成。');
  }
}
