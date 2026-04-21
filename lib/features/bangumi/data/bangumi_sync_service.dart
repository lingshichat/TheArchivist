import '../../../shared/data/app_database.dart';
import '../../../shared/utils/step_logger.dart';

abstract class BangumiSyncService {
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  });
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
     *   1) 满足 WP2 的注入式同步接口合同
     *   2) 在 WP3 真正落地前保持 quick add 主流程可运行
     */
    _logger.info('开始跳过 Bangumi 同步占位实现...');

    // 1.1 当前实现不做远程调用，只保留接口兼容
    final _ = (mediaItemId, status, score);

    _logger.info('跳过 Bangumi 同步占位实现完成。');
  }
}
