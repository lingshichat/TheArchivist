import 'package:drift/drift.dart';

import '../app_database.dart';
import '../daos/media_dao.dart';
import '../device_identity.dart';
import '../source_id_map.dart';
import '../sync_stamp.dart';
import '../../utils/step_logger.dart';

class MediaRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('MediaRepository');

  MediaRepository(this._db, {DeviceIdentityService? deviceIdentityService})
    : _deviceIdentityService =
          deviceIdentityService ?? DeviceIdentityService();

  // --- Home page ---

  Stream<List<MediaItemWithUserEntry>> watchContinuing({int limit = 20}) =>
      _db.mediaDao.watchContinuing(limit: limit);

  Stream<List<MediaItemWithUserEntry>> watchRecentlyAdded({int limit = 20}) =>
      _db.mediaDao.watchRecentlyAdded(limit: limit);

  Stream<List<MediaItemWithUserEntry>> watchRecentlyFinished({
    int limit = 20,
  }) => _db.mediaDao.watchRecentlyFinished(limit: limit);

  // --- Library ---

  Stream<List<MediaItemWithUserEntry>> watchLibrary({
    MediaType? type,
    List<MediaType>? types,
    String? status,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) => _db.mediaDao.watchLibrary(
    type: type,
    types: types,
    status: status,
    sortBy: sortBy,
    descending: descending,
  );

  // --- Detail ---

  Stream<MediaItem> watchItem(String id) => _db.mediaDao.watchItem(id);

  Stream<MediaItemWithUserEntry?> watchDetailBase(String id) =>
      _db.mediaDao.watchDetailBase(id);

  Future<MediaItem?> getItem(String id) async {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<MediaItem?> findBySourceId(String provider, String sourceId) async {
    /*
     * ========================================================================
     * 步骤1：按外部来源 ID 查找本地条目
     * ========================================================================
     * 目标：
     *   1) 让 quick add 在本地写入前先做去重判断
     *   2) 继续复用统一的 `sourceIdsJson` 存储结构
     */

    // 1.1 取出全部未删除的本地条目
    final items = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.deletedAt.isNull())).get();

    // 1.2 逐条匹配目标 provider/sourceId
    for (final item in items) {
      final existingSourceId = SourceIdMap.get(item.sourceIdsJson, provider);
      if (existingSourceId == sourceId) {
        return item;
      }
    }

    // 1.3 未命中时返回空
    return null;
  }

  // --- Write ---

  Future<String> createItem({
    required MediaType mediaType,
    required String title,
    String? subtitle,
    String? posterUrl,
    DateTime? releaseDate,
    String? overview,
    String? sourceIdsJson,
    int? runtimeMinutes,
    int? totalEpisodes,
    int? totalPages,
    double? estimatedPlayHours,
  }) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.mediaDao.upsertItem(
      MediaItemsCompanion.insert(
        id: id,
        mediaType: mediaType,
        title: title,
        subtitle: Value(subtitle),
        posterUrl: Value(posterUrl),
        releaseDate: Value(releaseDate),
        overview: Value(overview),
        sourceIdsJson: Value(sourceIdsJson ?? '{}'),
        runtimeMinutes: Value(runtimeMinutes),
        totalEpisodes: Value(totalEpisodes),
        totalPages: Value(totalPages),
        estimatedPlayHours: Value(estimatedPlayHours),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

    // Create a default user entry
    await _db.userEntryDao.upsert(
      UserEntriesCompanion.insert(
        id: DeviceIdentityService.generate(),
        mediaItemId: id,
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

    return id;
  }

  Future<void> softDelete(String id) async {
    final deviceId = await _getDeviceId();
    await _db.mediaDao.softDelete(id, deviceId);
  }

  Future<void> applyRemoteMetadata({
    required String mediaItemId,
    required MediaType mediaType,
    required String title,
    String? subtitle,
    String? posterUrl,
    DateTime? releaseDate,
    String? overview,
    String? sourceIdsJson,
    int? runtimeMinutes,
    int? totalEpisodes,
    int? totalPages,
    double? estimatedPlayHours,
  }) async {
    /*
     * ========================================================================
     * 步骤2：写入远端回拉得到的媒体元数据
     * ========================================================================
     * 目标：
     *   1) 让 Bangumi pull 在共享仓储层更新本地媒体基础字段
     *   2) 保留原有 createdAt，并由仓储统一补 updatedAt / deviceId
     */
    _logger.info('开始写入远端回拉媒体元数据...');

    // 2.1 读取现有条目；不存在时直接拒绝调用方误用
    final existing = await getItem(mediaItemId);
    if (existing == null) {
      _logger.info('远端回拉媒体元数据写入失败。');
      throw StateError('Media item not found.');
    }

    // 2.2 用最新远端字段刷新本地媒体条目
    final now = SyncStampDecorator.now();
    final deviceId = await _getDeviceId();
    await _db.mediaDao.upsertItem(
      MediaItemsCompanion.insert(
        id: mediaItemId,
        mediaType: mediaType,
        title: title,
        subtitle: Value(subtitle),
        posterUrl: Value(posterUrl),
        releaseDate: Value(releaseDate),
        overview: Value(overview),
        sourceIdsJson: Value(sourceIdsJson ?? existing.sourceIdsJson),
        runtimeMinutes: Value(runtimeMinutes),
        totalEpisodes: Value(totalEpisodes),
        totalPages: Value(totalPages),
        estimatedPlayHours: Value(estimatedPlayHours),
        createdAt: existing.createdAt,
        updatedAt: now,
        deletedAt: Value(existing.deletedAt),
        syncVersion: Value(existing.syncVersion),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(existing.lastSyncedAt),
      ),
    );

    _logger.info('远端回拉媒体元数据写入完成。');
  }

  Future<void> markSynced(String mediaItemId, DateTime syncedAt) async {
    /*
     * ========================================================================
     * 步骤3：标记媒体条目最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 让 pull / push 成功后留下稳定的 lastSyncedAt
     *   2) 不改动媒体条目的业务更新时间语义
     */
    _logger.info('开始标记媒体条目同步时间...');

    // 3.1 读取现有条目；缺失时直接跳过
    final existing = await getItem(mediaItemId);
    if (existing == null) {
      _logger.info('媒体条目同步时间标记完成。');
      return;
    }

    // 3.2 仅更新 lastSyncedAt 与 deviceId，保留原有业务字段
    final deviceId = await _getDeviceId();
    await _db.mediaDao.markSynced(mediaItemId, syncedAt, deviceId);

    _logger.info('媒体条目同步时间标记完成。');
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
