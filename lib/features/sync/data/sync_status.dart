import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/sync_stamp.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_queue.dart';

class SyncStatusState {
  const SyncStatusState({
    this.isRunning = false,
    this.lastCompletedAt,
    this.lastErrorSummary,
    this.pendingCount = 0,
    this.hasConflicts = false,
  });

  final bool isRunning;
  final DateTime? lastCompletedAt;
  final String? lastErrorSummary;
  final int pendingCount;
  final bool hasConflicts;

  SyncStatusState copyWith({
    bool? isRunning,
    Object? lastCompletedAt = _noOverride,
    Object? lastErrorSummary = _noOverride,
    int? pendingCount,
    bool? hasConflicts,
  }) {
    return SyncStatusState(
      isRunning: isRunning ?? this.isRunning,
      lastCompletedAt: identical(lastCompletedAt, _noOverride)
          ? this.lastCompletedAt
          : lastCompletedAt as DateTime?,
      lastErrorSummary: identical(lastErrorSummary, _noOverride)
          ? this.lastErrorSummary
          : lastErrorSummary as String?,
      pendingCount: pendingCount ?? this.pendingCount,
      hasConflicts: hasConflicts ?? this.hasConflicts,
    );
  }
}

class SyncStatusRepository {
  SyncStatusRepository({required AppDatabase database, StepLogger? logger})
    : _database = database,
      _logger = logger ?? const StepLogger('SyncStatusRepository');

  static const String singletonId = 'default_sync_status';

  final AppDatabase _database;
  final StepLogger _logger;

  Stream<SyncStatusState> watchStatus() {
    return _database.syncStatusDao
        .watchById(singletonId)
        .map(_mapOrDefaultState);
  }

  Future<SyncStatusState> readStatus() async {
    final row = await _database.syncStatusDao.getById(singletonId);
    return _mapOrDefaultState(row);
  }

  Future<void> setStatus({
    required bool isRunning,
    required int pendingCount,
    String? lastErrorSummary,
    DateTime? lastCompletedAt,
    bool hasConflicts = false,
  }) async {
    /*
     * ========================================================================
     * 步骤1：写入最小同步状态快照
     * ========================================================================
     * 目标：
     *   1) 持久化运行中、最近完成时间、失败摘要和待处理数量
     *   2) 让设置页与后续引擎共享同一状态来源
     */
    _logger.info('开始写入最小同步状态快照...');

    // 1.1 用统一 DAO 入口覆盖当前同步快照
    await _database.syncStatusDao.updateSnapshot(
      id: singletonId,
      isRunning: isRunning,
      updatedAt: SyncStampDecorator.now(),
      pendingCount: pendingCount,
      hasConflicts: hasConflicts,
      lastCompletedAt: lastCompletedAt,
      lastErrorSummary: _normalizeOptional(lastErrorSummary),
    );

    _logger.info('最小同步状态快照写入完成。');
  }

  SyncStatusState _mapOrDefaultState(SyncStatusEntry? row) {
    if (row == null) {
      return const SyncStatusState();
    }

    return SyncStatusState(
      isRunning: row.isRunning,
      lastCompletedAt: row.lastCompletedAt,
      lastErrorSummary: row.lastErrorSummary,
      pendingCount: row.pendingCount,
      hasConflicts: row.hasConflicts,
    );
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class SyncStatusController extends StateNotifier<SyncStatusState> {
  SyncStatusController({
    required SyncStatusRepository statusRepository,
    required SyncQueueRepository queueRepository,
    StepLogger? logger,
  }) : _statusRepository = statusRepository,
       _queueRepository = queueRepository,
       _logger = logger ?? const StepLogger('SyncStatusController'),
       super(const SyncStatusState()) {
    _initialize();
  }

  final SyncStatusRepository _statusRepository;
  final SyncQueueRepository _queueRepository;
  final StepLogger _logger;

  Future<void> _initialize() async {
    final currentState = await _statusRepository.readStatus();
    state = currentState;
  }

  Future<void> refreshPendingCount() async {
    /*
     * ========================================================================
     * 步骤1：刷新同步待处理数量
     * ========================================================================
     * 目标：
     *   1) 用队列真实待处理数量覆盖状态快照
     *   2) 保持状态中心与本地队列一致
     */
    _logger.info('开始刷新同步待处理数量...');

    // 1.1 读取队列待处理条目数量并回写状态
    final pendingCount = await _queueRepository.watchPendingCount().first;
    state = state.copyWith(pendingCount: pendingCount);
    await _statusRepository.setStatus(
      isRunning: state.isRunning,
      pendingCount: pendingCount,
      lastErrorSummary: state.lastErrorSummary,
      lastCompletedAt: state.lastCompletedAt,
      hasConflicts: state.hasConflicts,
    );

    _logger.info('同步待处理数量刷新完成。');
  }

  Future<void> markRunning() async {
    /*
     * ========================================================================
     * 步骤2：标记同步开始
     * ========================================================================
     * 目标：
     *   1) 在同步任务启动时记录 running 状态
     *   2) 清空上一次失败摘要的脏状态
     */
    _logger.info('开始标记同步开始...');

    // 2.1 读取最新待处理数量并写入运行中状态
    final pendingCount = await _queueRepository.watchPendingCount().first;
    state = state.copyWith(
      isRunning: true,
      pendingCount: pendingCount,
      lastErrorSummary: null,
    );
    await _statusRepository.setStatus(
      isRunning: true,
      pendingCount: pendingCount,
      lastCompletedAt: state.lastCompletedAt,
      hasConflicts: state.hasConflicts,
    );

    _logger.info('同步开始标记完成。');
  }

  Future<void> markCompleted({String? errorSummary}) async {
    /*
     * ========================================================================
     * 步骤3：标记同步结束
     * ========================================================================
     * 目标：
     *   1) 在同步任务结束时更新最近完成时间和失败摘要
     *   2) 让最小状态面板能直接显示结果
     */
    _logger.info('开始标记同步结束...');

    // 3.1 读取最新待处理数量并写入完成快照
    final pendingCount = await _queueRepository.watchPendingCount().first;
    final completedAt = SyncStampDecorator.now();
    state = state.copyWith(
      isRunning: false,
      pendingCount: pendingCount,
      lastCompletedAt: completedAt,
      lastErrorSummary: _normalizeOptional(errorSummary),
    );
    await _statusRepository.setStatus(
      isRunning: false,
      pendingCount: pendingCount,
      lastCompletedAt: completedAt,
      lastErrorSummary: errorSummary,
      hasConflicts: state.hasConflicts,
    );

    _logger.info('同步结束标记完成。');
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

const Object _noOverride = Object();
