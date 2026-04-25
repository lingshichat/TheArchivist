import '../../../shared/data/app_database.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/progress_repository.dart';
import '../../../shared/data/source_id_map.dart';
import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_api_service.dart';
import 'bangumi_sync_feedback.dart';
import 'bangumi_token_store.dart';

abstract class BangumiProgressSyncService {
  Future<void> pushProgress({required String mediaItemId});
}

class BangumiProgressSyncServiceImpl implements BangumiProgressSyncService {
  BangumiProgressSyncServiceImpl({
    required BangumiApiService apiService,
    required MediaRepository mediaRepository,
    required ProgressRepository progressRepository,
    required BangumiTokenStore tokenStore,
    required BangumiSyncFeedbackController feedbackController,
    required Future<void> Function() onUnauthorized,
    StepLogger? logger,
  })  : _apiService = apiService,
        _mediaRepository = mediaRepository,
        _progressRepository = progressRepository,
        _tokenStore = tokenStore,
        _feedbackController = feedbackController,
        _onUnauthorized = onUnauthorized,
        _logger = logger ?? const StepLogger('BangumiProgressSyncService');

  final BangumiApiService _apiService;
  final MediaRepository _mediaRepository;
  final ProgressRepository _progressRepository;
  final BangumiTokenStore _tokenStore;
  final BangumiSyncFeedbackController _feedbackController;
  final Future<void> Function() _onUnauthorized;
  final StepLogger _logger;

  @override
  Future<void> pushProgress({required String mediaItemId}) async {
    /*
     * ========================================================================
     * 步骤1：校验前置条件
     * ========================================================================
     * 目标：
     *   1) 确认用户已登录 Bangumi
     *   2) 确认本地媒体条目存在且已关联 Bangumi ID
     */
    _logger.info('开始校验 Bangumi 进度同步前置条件...');

    // 1.1 读取本地 token，未登录时直接跳过
    final token = await _tokenStore.read();
    if (token == null) {
      _logger.info('未登录 Bangumi，跳过进度同步。');
      return;
    }

    // 1.2 读取本地媒体条目并提取 Bangumi 来源 ID
    final mediaItem = await _mediaRepository.getItem(mediaItemId);
    final bangumiId = int.tryParse(
      SourceIdMap.get(mediaItem?.sourceIdsJson, 'bangumi') ?? '',
    );
    if (mediaItem == null || bangumiId == null) {
      _logger.info('本地条目不存在或未关联 Bangumi ID，跳过进度同步。');
      return;
    }

    /*
     * ========================================================================
     * 步骤2：读取本地进度
     * ========================================================================
     * 目标：
     *   1) 获取当前媒体条目的本地进度记录
     *   2) 无进度记录时跳过同步
     */
    _logger.info('开始读取本地进度...');

    final progress = await _progressRepository.getByMediaItemId(mediaItemId);
    if (progress == null) {
      _logger.info('无本地进度记录，跳过同步。');
      return;
    }

    /*
     * ========================================================================
     * 步骤3：映射进度为 Bangumi ep_status
     * ========================================================================
     * 目标：
     *   1) 按媒体类型把本地进度映射为 Bangumi 的 ep_status 语义
     *   2) TV 用 currentEpisode，书籍用 currentPage，其余类型不支持
     */
    _logger.info('开始映射本地进度为 Bangumi ep_status...');

    final int? epStatus = _mapProgressToEpStatus(mediaItem.mediaType, progress);
    if (epStatus == null) {
      _logger.info('当前媒体类型不支持进度同步。');
      return;
    }

    /*
     * ========================================================================
     * 步骤4：推送进度到 Bangumi
     * ========================================================================
     * 目标：
     *   1) 通过 PATCH 接口更新远端收藏进度
     *   2) 成功后标记本地进度已同步
     */
    _logger.info('开始推送进度到 Bangumi...');

    try {
      await _apiService.patchCollection(bangumiId, <String, Object?>{
        'ep_status': epStatus,
      });

      // 4.1 标记本地进度最近一次同步时间
      final syncedAt = DateTime.now();
      await _progressRepository.markSynced(mediaItemId, syncedAt);

      _logger.info('Bangumi 进度同步成功。');
      _feedbackController.publishSuccess('Progress synced to Bangumi.');
    } on BangumiUnauthorizedError catch (_) {
      _logger.info('Bangumi 认证已过期。');
      await _onUnauthorized();
      _feedbackController.publishFailure(
        'Bangumi connection expired. Reconnect in Settings.',
      );
    } on BangumiApiException catch (error) {
      _logger.info('Bangumi 进度同步失败：${error.message}');
      _feedbackController.publishFailure(_messageForError(error));
    }
  }

  int? _mapProgressToEpStatus(MediaType mediaType, ProgressEntry progress) {
    switch (mediaType) {
      case MediaType.tv:
        return progress.currentEpisode;
      case MediaType.book:
        return progress.currentPage;
      case MediaType.movie:
      case MediaType.game:
        return null;
    }
  }

  String _messageForError(BangumiApiException error) {
    switch (error) {
      case BangumiNetworkError():
        return 'Saved locally. Bangumi progress sync failed: network unavailable.';
      case BangumiBadRequestError():
        return 'Saved locally. Bangumi rejected the progress sync.';
      case BangumiNotFoundError():
        return 'Saved locally. This Bangumi item could not be found remotely.';
      case BangumiServerError():
        return 'Saved locally. Bangumi is temporarily unavailable.';
      case BangumiUnknownError():
        return 'Saved locally. Bangumi progress sync failed unexpectedly.';
      case BangumiUnauthorizedError():
        return 'Bangumi connection expired. Reconnect in Settings.';
    }
  }
}

class NoopBangumiProgressSyncService implements BangumiProgressSyncService {
  const NoopBangumiProgressSyncService();

  @override
  Future<void> pushProgress({required String mediaItemId}) async {
    final _ = mediaItemId;
  }
}
