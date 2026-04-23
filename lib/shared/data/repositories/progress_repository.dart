import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';
import '../../utils/step_logger.dart';

class ProgressRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('ProgressRepository');

  ProgressRepository(
    this._db, {
    DeviceIdentityService? deviceIdentityService,
  }) : _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();

  Stream<ProgressEntry?> watchByMediaItemId(String mediaItemId) {
    return _db.progressDao.watchByMediaItemId(mediaItemId);
  }

  Future<ProgressEntry?> getByMediaItemId(String mediaItemId) {
    return _db.progressDao.getByMediaItemId(mediaItemId);
  }

  Future<void> updateProgress(
    String mediaItemId, {
    int? currentEpisode,
    int? currentPage,
    double? currentMinutes,
    double? completionRatio,
  }) async {
    final deviceId = await _getDeviceId();

    final existing = await _db.progressDao.getByMediaItemId(mediaItemId);
    if (existing == null) {
      final now = SyncStampDecorator.now();
      await _db.progressDao.upsert(
        ProgressEntriesCompanion.insert(
          id: DeviceIdentityService.generate(),
          mediaItemId: mediaItemId,
          currentEpisode: Value(currentEpisode),
          currentPage: Value(currentPage),
          currentMinutes: Value(currentMinutes),
          completionRatio: Value(completionRatio),
          createdAt: now,
          updatedAt: now,
          deviceId: Value(deviceId),
        ),
      );
    } else {
      await _db.progressDao.updateProgress(
        mediaItemId,
        deviceId,
        currentEpisode: currentEpisode,
        currentPage: currentPage,
        currentMinutes: currentMinutes,
        completionRatio: completionRatio,
      );
    }
  }

  Future<void> applyRemoteProgress(
    String mediaItemId, {
    int? currentEpisode,
    int? currentPage,
    double? currentMinutes,
    double? completionRatio,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：应用远端回拉得到的进度
     * ========================================================================
     * 目标：
     *   1) 为后续 sync engine 提供统一的 progress 写回入口
     *   2) 同步补齐 updatedAt / lastSyncedAt / deviceId 等同步字段
     */
    _logger.info('开始应用远端回拉进度...');

    // 1.1 读取现有进度行，决定走补建还是覆盖
    final existing = await _db.progressDao.getByMediaItemId(mediaItemId);
    final deviceId = await _getDeviceId();

    // 1.2 用 upsert 保证缺失行会补建，已有行会覆盖同步字段
    await _db.progressDao.upsert(
      ProgressEntriesCompanion.insert(
        id: existing?.id ?? DeviceIdentityService.generate(),
        mediaItemId: mediaItemId,
        currentEpisode: Value(currentEpisode),
        currentPage: Value(currentPage),
        currentMinutes: Value(currentMinutes),
        completionRatio: Value(completionRatio),
        createdAt: existing?.createdAt ?? syncedAt,
        updatedAt: syncedAt,
        deletedAt: Value(existing?.deletedAt),
        syncVersion: Value(existing?.syncVersion ?? 0),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('远端回拉进度应用完成。');
  }

  Future<void> markSynced(String mediaItemId, DateTime syncedAt) async {
    /*
     * ========================================================================
     * 步骤2：标记进度条目最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 让 push / pull 成功后沉淀 progress 的 lastSyncedAt
     *   2) 不改写当前进度业务字段
     */
    _logger.info('开始标记进度条目同步时间...');

    // 2.1 缺失时直接跳过，避免额外补建空进度行
    final existing = await _db.progressDao.getByMediaItemId(mediaItemId);
    if (existing == null) {
      _logger.info('进度条目同步时间标记完成。');
      return;
    }

    // 2.2 仅写入同步标记字段
    final deviceId = await _getDeviceId();
    await _db.progressDao.markSynced(mediaItemId, syncedAt, deviceId);

    _logger.info('进度条目同步时间标记完成。');
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
