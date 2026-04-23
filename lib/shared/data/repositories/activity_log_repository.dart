import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';
import '../../utils/step_logger.dart';

class ActivityLogRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('ActivityLogRepository');

  ActivityLogRepository(
    this._db, {
    DeviceIdentityService? deviceIdentityService,
  }) : _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();

  Stream<List<ActivityLog>> watchByMediaItemId(String mediaItemId) {
    return _db.activityLogDao.watchByMediaItemId(mediaItemId);
  }

  Future<void> appendEvent(
    String mediaItemId,
    ActivityEvent event, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    /*
     * ========================================================================
     * 步骤1：追加本地活动日志事件
     * ========================================================================
     * 目标：
     *   1) 在本地事件发生时追加一条可追踪日志
     *   2) 统一补齐活动日志的同步字段
     */
    _logger.info('开始追加本地活动日志事件...');

    // 1.1 生成本地日志行并落库
    final now = SyncStampDecorator.now();
    final deviceId = await _getDeviceId();

    await _db.activityLogDao.insertLog(
      ActivityLogsCompanion.insert(
        id: DeviceIdentityService.generate(),
        mediaItemId: mediaItemId,
        event: event,
        payloadJson: Value(jsonEncode(payload)),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

    _logger.info('本地活动日志事件追加完成。');
  }

  Future<void> applyRemoteSnapshot({
    required String id,
    required String mediaItemId,
    required ActivityEvent event,
    required String payloadJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    int syncVersion = 0,
    DateTime? lastSyncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：应用跨设备同步活动日志快照
     * ========================================================================
     * 目标：
     *   1) 让 sync engine 能按远端快照补建或覆盖活动日志
     *   2) 保留远端的 createdAt / updatedAt / deletedAt / lastSyncedAt 语义
     */
    _logger.info('开始应用跨设备同步活动日志快照...');

    // 2.1 用统一 upsert 入口覆盖活动日志快照
    final deviceId = await _getDeviceId();
    await _db.activityLogDao.upsert(
      ActivityLogsCompanion.insert(
        id: id,
        mediaItemId: mediaItemId,
        event: event,
        payloadJson: Value(payloadJson),
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: Value(deletedAt),
        syncVersion: Value(syncVersion),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(lastSyncedAt),
      ),
    );

    _logger.info('跨设备同步活动日志快照应用完成。');
  }

  Future<void> markSynced(String id, DateTime syncedAt) async {
    /*
     * ========================================================================
     * 步骤3：标记活动日志最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 为活动日志的 push / pull 成功路径记录 lastSyncedAt
     *   2) 不改写事件类型与负载
     */
    _logger.info('开始标记活动日志同步时间...');

    // 3.1 仅更新活动日志同步标记字段
    final deviceId = await _getDeviceId();
    await _db.activityLogDao.markSynced(id, syncedAt, deviceId);

    _logger.info('活动日志同步时间标记完成。');
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
