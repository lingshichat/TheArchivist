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
    : _deviceIdentityService =
          deviceIdentityService ?? DeviceIdentityService();

  Stream<List<ShelfList>> watchAll() => _db.shelfDao.watchAll();

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

  Future<void> attachToMedia(String mediaItemId, String shelfListId) async {
    final deviceId = await _getDeviceId();
    await _db.shelfDao.attachOrRestore(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      id: DeviceIdentityService.generate(),
      deviceId: deviceId,
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
      id: DeviceIdentityService.generate(),
      deviceId: deviceId,
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

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
