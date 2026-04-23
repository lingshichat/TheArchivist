import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../../utils/step_logger.dart';

class UserEntryRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('UserEntryRepository');

  UserEntryRepository(
    this._db, {
    DeviceIdentityService? deviceIdentityService,
  }) : _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();

  Stream<UserEntry?> watchByMediaItemId(String mediaItemId) {
    return _db.userEntryDao.watchByMediaItemId(mediaItemId);
  }

  Future<UserEntry?> getByMediaItemId(String mediaItemId) {
    return _db.userEntryDao.getByMediaItemId(mediaItemId);
  }

  Future<void> updateStatus(String mediaItemId, UnifiedStatus status) async {
    final deviceId = await _getDeviceId();
    final existing = await _db.userEntryDao.getByMediaItemId(mediaItemId);
    final now = DateTime.now();

    Value<DateTime?> startedAt = const Value.absent();
    Value<DateTime?> finishedAt = const Value.absent();

    if (status == UnifiedStatus.inProgress && existing?.startedAt == null) {
      startedAt = Value(now);
    }

    if (status == UnifiedStatus.done) {
      startedAt = Value(existing?.startedAt ?? now);
      finishedAt = Value(now);
    } else if (existing?.finishedAt != null) {
      finishedAt = const Value(null);
    }

    await _db.userEntryDao.updateStatus(
      mediaItemId,
      status,
      deviceId,
      startedAt,
      finishedAt,
    );
  }

  Future<void> updateScore(String mediaItemId, int? score) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.updateScore(mediaItemId, score, deviceId);
  }

  Future<void> updateNotes(String mediaItemId, String? notes) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.updateNotes(mediaItemId, notes, deviceId);
  }

  Future<void> toggleFavorite(String mediaItemId, bool favorite) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.toggleFavorite(mediaItemId, favorite, deviceId);
  }

  Future<void> applyRemoteStatusAndScore(
    String mediaItemId, {
    UnifiedStatus? status,
    int? score,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：应用远端回拉得到的状态和评分
     * ========================================================================
     * 目标：
     *   1) 让 Bangumi pull 在仓储层统一落库 status / score
     *   2) 同步补齐 updatedAt / lastSyncedAt / deviceId 等同步字段
     */
    _logger.info('开始应用远端回拉状态和评分...');

    // 1.1 读取现有 user entry；不存在时补建默认行
    final existing = await _db.userEntryDao.getByMediaItemId(mediaItemId);
    final deviceId = await _getDeviceId();
    final nextStatus = status ?? existing?.status ?? UnifiedStatus.wishlist;

    Value<DateTime?> startedAt = Value(existing?.startedAt);
    Value<DateTime?> finishedAt = Value(existing?.finishedAt);

    if (status != null) {
      if (nextStatus == UnifiedStatus.inProgress &&
          existing?.startedAt == null) {
        startedAt = Value(syncedAt);
      }

      if (nextStatus == UnifiedStatus.done) {
        startedAt = Value(existing?.startedAt ?? syncedAt);
        finishedAt = Value(syncedAt);
      } else if (existing?.finishedAt != null) {
        finishedAt = const Value(null);
      }
    }

    // 1.2 用 upsert 保证已有行更新、缺失行自动补齐
    await _db.userEntryDao.upsert(
      UserEntriesCompanion.insert(
        id: existing?.id ?? DeviceIdentityService.generate(),
        mediaItemId: mediaItemId,
        status: Value(nextStatus),
        score: Value(score),
        review: Value(existing?.review),
        notes: Value(existing?.notes),
        favorite: Value(existing?.favorite ?? false),
        reconsumeCount: Value(existing?.reconsumeCount ?? 0),
        startedAt: startedAt,
        finishedAt: finishedAt,
        createdAt: existing?.createdAt ?? syncedAt,
        updatedAt: syncedAt,
        deletedAt: Value(existing?.deletedAt),
        syncVersion: Value(existing?.syncVersion ?? 0),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('远端回拉状态和评分应用完成。');
  }

  Future<void> markSynced(String mediaItemId, DateTime syncedAt) async {
    /*
     * ========================================================================
     * 步骤2：标记用户条目最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 让 push / pull 成功后沉淀 lastSyncedAt
     *   2) 不改写 status / score 等业务字段
     */
    _logger.info('开始标记用户条目同步时间...');

    // 2.1 读取现有 user entry；不存在时不额外补建
    final existing = await _db.userEntryDao.getByMediaItemId(mediaItemId);
    if (existing == null) {
      _logger.info('用户条目同步时间标记完成。');
      return;
    }

    // 2.2 仅写入 lastSyncedAt 与 deviceId，保留原有更新时间
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.markSynced(mediaItemId, syncedAt, deviceId);

    _logger.info('用户条目同步时间标记完成。');
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
