import '../../../shared/utils/step_logger.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';
import 'sync_status.dart';
import 'sync_storage_adapter.dart';
import 'sync_summary.dart';

class SyncOperationsService {
  SyncOperationsService({
    required SyncEngine engine,
    required SyncStatusController statusController,
    required SyncQueueRepository queueRepository,
    StepLogger? logger,
  }) : _engine = engine,
       _statusController = statusController,
       _queueRepository = queueRepository,
       _logger = logger ?? const StepLogger('SyncOperationsService');

  final SyncEngine _engine;
  final SyncStatusController _statusController;
  final SyncQueueRepository _queueRepository;
  final StepLogger _logger;

  Future<SyncSummary> runSyncWithConfig(
    SyncStorageAdapter adapter,
  ) async {
    _logger.info('开始执行手动同步...');
    final summary = await _engine.runSync(adapter: adapter);
    await _statusController.refreshPendingCount();
    _logger.info('手动同步执行完成。');
    return summary;
  }

  Future<List<SyncQueueItem>> listPendingItems({int limit = 100}) async {
    return _queueRepository.listPending(limit: limit);
  }

  Future<void> retryAllPending(SyncStorageAdapter adapter) async {
    _logger.info('开始重试所有待同步项...');
    await _engine.runSync(adapter: adapter);
    await _statusController.refreshPendingCount();
    _logger.info('重试执行完成。');
  }
}
