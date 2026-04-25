import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';
import '../../utils/step_logger.dart';

class ShelfRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('ShelfRepository');

  ShelfRepository(this._db, {DeviceIdentityService? deviceIdentityService})
    : _deviceIdentityService = deviceIdentityService ?? DeviceIdentityService();

  Stream<List<ShelfList>> watchAll() => _db.shelfDao.watchAll();

  Stream<List<ShelfList>> watchUserShelves() => _db.shelfDao.watchUserShelves();

  Stream<List<ShelfList>> watchByMediaItemId(String mediaItemId) {
    return _db.shelfDao.watchByMediaItemId(mediaItemId);
  }

  Future<List<ShelfList>> getByMediaItemId(String mediaItemId) {
    return _db.shelfDao.getByMediaItemId(mediaItemId);
  }

  Future<String> createShelf({
    required String name,
    ShelfKind kind = ShelfKind.user,
  }) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.shelfDao.upsert(
      ShelfListsCompanion.insert(
        id: id,
        name: name,
        kind: kind,
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

    return id;
  }

  Future<void> applyRemoteSnapshot({
    required String shelfListId,
    required String name,
    required ShelfKind kind,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    int syncVersion = 0,
    DateTime? lastSyncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：应用跨设备同步书架快照
     * ========================================================================
     * 目标：
     *   1) 让 sync engine 能按远端快照补建或覆盖书架定义
     *   2) 保留远端的 createdAt / updatedAt / deletedAt / lastSyncedAt 语义
     */
    _logger.info('开始应用跨设备同步书架快照...');

    // 1.1 用统一 upsert 入口覆盖书架定义
    final deviceId = await _getDeviceId();
    await _db.shelfDao.upsert(
      ShelfListsCompanion.insert(
        id: shelfListId,
        name: name,
        kind: kind,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: Value(deletedAt),
        syncVersion: Value(syncVersion),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(lastSyncedAt),
      ),
    );

    _logger.info('跨设备同步书架快照应用完成。');
  }

  Future<void> attachToMedia(String mediaItemId, String shelfListId) async {
    final deviceId = await _getDeviceId();
    await _db.shelfDao.attachOrRestore(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      id: DeviceIdentityService.generate(),
      deviceId: deviceId,
      updatedAt: SyncStampDecorator.now(),
      syncedAt: null,
    );
  }

  Future<void> detachFromMedia(String mediaItemId, String shelfListId) async {
    final deviceId = await _getDeviceId();
    await _db.shelfDao.detach(mediaItemId, shelfListId, deviceId);
  }

  Future<void> syncShelvesForMedia(
    String mediaItemId,
    Iterable<String> rawNames,
  ) async {
    final desiredNames = _normalizeNames(rawNames);
    final existingShelves = await _db.shelfDao.getAll();
    final currentShelves = await _db.shelfDao.getByMediaItemId(mediaItemId);

    final existingByName = <String, ShelfList>{
      for (final shelf in existingShelves) shelf.name.toLowerCase(): shelf,
    };
    final currentIds = currentShelves.map((e) => e.id).toSet();
    final desiredIds = <String>{};

    for (final name in desiredNames) {
      final key = name.toLowerCase();
      final existing = existingByName[key];
      final shelfId = existing?.id ?? await createShelf(name: name);
      desiredIds.add(shelfId);

      if (!currentIds.contains(shelfId)) {
        await attachToMedia(mediaItemId, shelfId);
      }
    }

    for (final shelf in currentShelves) {
      if (!desiredIds.contains(shelf.id)) {
        await detachFromMedia(mediaItemId, shelf.id);
      }
    }
  }

  List<String> _normalizeNames(Iterable<String> rawNames) {
    final seen = <String>{};
    final names = <String>[];

    for (final rawName in rawNames) {
      final normalized = rawName.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        names.add(normalized);
      }
    }

    return names;
  }

  Future<void> applyRemoteAttachment({
    required String mediaItemId,
    required String shelfListId,
    String? linkId,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：应用远端回拉得到的书架关联
     * ========================================================================
     * 目标：
     *   1) 为后续 sync engine 提供统一的 shelf attach 写回入口
     *   2) 保证 join 表记录具备同步字段
     */
    _logger.info('开始应用远端回拉书架关联...');

    // 1.1 读取当前设备 ID，并用 sync-aware 方式补写关联
    final deviceId = await _getDeviceId();
    await _db.shelfDao.attachOrRestore(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      id: linkId ?? DeviceIdentityService.generate(),
      deviceId: deviceId,
      updatedAt: syncedAt,
      syncedAt: syncedAt,
    );

    _logger.info('远端回拉书架关联应用完成。');
  }

  Future<void> applyRemoteDetachment({
    required String mediaItemId,
    required String shelfListId,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：应用远端回拉得到的书架解绑
     * ========================================================================
     * 目标：
     *   1) 为后续 sync engine 提供统一的 shelf detach 写回入口
     *   2) 统一走软删除而不是直接硬删
     */
    _logger.info('开始应用远端回拉书架解绑...');

    // 2.1 仅更新 join 表删除标记，保留同步字段语义
    final deviceId = await _getDeviceId();
    await _db.shelfDao.softDetach(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      deviceId: deviceId,
      updatedAt: syncedAt,
      syncedAt: syncedAt,
    );

    _logger.info('远端回拉书架解绑应用完成。');
  }

  Future<void> markShelfLinkSynced(
    String mediaItemId,
    String shelfListId,
    DateTime syncedAt,
  ) async {
    /*
     * ========================================================================
     * 步骤3：标记书架关联最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 为 push / pull 成功路径补写 join 表同步戳
     *   2) 保持关联业务关系不被额外改写
     */
    _logger.info('开始标记书架关联同步时间...');

    // 3.1 仅更新 join 表同步标记字段
    final deviceId = await _getDeviceId();
    await _db.shelfDao.markLinkSynced(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      syncedAt: syncedAt,
      deviceId: deviceId,
    );

    _logger.info('书架关联同步时间标记完成。');
  }

  Future<void> markSynced(String shelfListId, DateTime syncedAt) async {
    /*
     * ========================================================================
     * 步骤4：标记书架定义最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 为书架定义的 push / pull 成功路径记录 lastSyncedAt
     *   2) 不改写书架名称与类型
     */
    _logger.info('开始标记书架定义同步时间...');

    // 4.1 仅更新书架定义同步标记字段
    final existing = await (_db.select(
      _db.shelfLists,
    )..where((t) => t.id.equals(shelfListId))).getSingleOrNull();
    if (existing == null) {
      _logger.info('书架定义同步时间标记完成。');
      return;
    }

    final deviceId = await _getDeviceId();
    await _db.shelfDao.upsert(
      ShelfListsCompanion.insert(
        id: existing.id,
        name: existing.name,
        kind: existing.kind,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
        deletedAt: Value(existing.deletedAt),
        syncVersion: Value(existing.syncVersion),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('书架定义同步时间标记完成。');
  }

  Future<int> countShelfItems(String shelfListId) {
    return _db.shelfDao.countMediaItemsByShelfId(shelfListId);
  }

  Stream<List<MediaItem>> watchShelfMediaItems(
    String shelfListId, {
    ShelfSortOption sortBy = ShelfSortOption.position,
  }) {
    return _db.shelfDao.watchMediaItemsByShelfId(
      shelfListId,
      sortBy: sortBy.field,
      descending: sortBy.descending,
    );
  }

  Future<void> renameShelf(String shelfListId, String newName) async {
    final deviceId = await _getDeviceId();
    await _db.shelfDao.renameShelf(shelfListId, newName, deviceId);
  }

  Future<void> softDeleteShelf(String shelfListId) async {
    final deviceId = await _getDeviceId();
    await _db.shelfDao.softDeleteShelf(shelfListId, deviceId);
  }

  Future<void> batchAttachToShelf(
    String shelfListId,
    List<String> mediaItemIds,
  ) async {
    final deviceId = await _getDeviceId();
    final now = SyncStampDecorator.now();

    for (final mediaItemId in mediaItemIds) {
      await _db.shelfDao.attachOrRestore(
        mediaItemId: mediaItemId,
        shelfListId: shelfListId,
        id: DeviceIdentityService.generate(),
        deviceId: deviceId,
        updatedAt: now,
        syncedAt: null,
      );
    }
  }

  Future<void> batchDetachFromShelf(
    String shelfListId,
    List<String> mediaItemIds,
  ) async {
    final deviceId = await _getDeviceId();
    final now = SyncStampDecorator.now();

    for (final mediaItemId in mediaItemIds) {
      await _db.shelfDao.softDetach(
        mediaItemId: mediaItemId,
        shelfListId: shelfListId,
        deviceId: deviceId,
        updatedAt: now,
        syncedAt: null,
      );
    }
  }

  Future<void> reorderShelfItems(
    String shelfListId,
    List<String> mediaItemIdsInOrder,
  ) async {
    for (var i = 0; i < mediaItemIdsInOrder.length; i++) {
      await _db.shelfDao.updatePosition(
        mediaItemIdsInOrder[i],
        shelfListId,
        (i + 1) * 1000,
      );
    }
  }

  Future<bool> isNameTaken(String name) async {
    final all = await _db.shelfDao.getAll();
    return all.any(
      (s) => s.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}

enum ShelfSortOption {
  position('position', false),
  recent('createdAt', true),
  title('title', false);

  const ShelfSortOption(this.field, this.descending);

  final String field;
  final bool descending;
}
