import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/media_item_shelves.dart';
import '../tables/shelf_lists.dart';
import '../../utils/step_logger.dart';

part 'shelf_dao.g.dart';

@DriftAccessor(tables: [ShelfLists, MediaItemShelves])
class ShelfDao extends DatabaseAccessor<AppDatabase> with _$ShelfDaoMixin {
  ShelfDao(super.db);

  static const StepLogger _logger = StepLogger('ShelfDao');

  Stream<List<ShelfList>> watchAll() {
    return (select(shelfLists)..where((t) => t.deletedAt.isNull())).watch();
  }

  Future<List<ShelfList>> getAll() {
    return (select(shelfLists)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<void> upsert(ShelfListsCompanion shelf) {
    return into(shelfLists).insertOnConflictUpdate(shelf);
  }

  Future<void> attach(
    String mediaItemId,
    String shelfListId,
    String id,
    String deviceId,
  ) {
    final now = DateTime.now();
    into(mediaItemShelves).insert(
      MediaItemShelvesCompanion.insert(
        id: id,
        mediaItemId: mediaItemId,
        shelfListId: shelfListId,
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );
    return Future.value();
  }

  Future<void> detach(
    String mediaItemId,
    String shelfListId,
    String deviceId,
  ) {
    return softDetach(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
      deviceId: deviceId,
      syncedAt: null,
    );
  }

  Future<void> attachOrRestore({
    required String mediaItemId,
    required String shelfListId,
    required String id,
    required String deviceId,
    required DateTime? syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：补写或恢复书架关联
     * ========================================================================
     * 目标：
     *   1) 让 join 表在 attach 时优先复用已存在记录
     *   2) 保持 deletedAt / lastSyncedAt / deviceId 语义一致
     */
    _logger.info('开始补写或恢复书架关联...');

    // 1.1 先查是否已有同 mediaItem/shelf 的 join 行
    final existing = await _findLink(
      mediaItemId: mediaItemId,
      shelfListId: shelfListId,
    );
    final now = DateTime.now();
    if (existing == null) {
      // 1.2 不存在时直接插入新关联
      await into(mediaItemShelves).insert(
        MediaItemShelvesCompanion.insert(
          id: id,
          mediaItemId: mediaItemId,
          shelfListId: shelfListId,
          createdAt: now,
          updatedAt: now,
          deletedAt: const Value(null),
          deviceId: Value(deviceId),
          lastSyncedAt: Value(syncedAt),
        ),
      );
      _logger.info('书架关联补写或恢复完成。');
      return;
    }

    // 1.3 已存在时恢复软删并刷新同步字段
    await (update(
      mediaItemShelves,
    )..where((t) => t.id.equals(existing.id))).write(
      MediaItemShelvesCompanion(
        updatedAt: Value(now),
        deletedAt: const Value(null),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('书架关联补写或恢复完成。');
  }

  Future<void> softDetach({
    required String mediaItemId,
    required String shelfListId,
    required String deviceId,
    required DateTime? syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：软删除书架关联
     * ========================================================================
     * 目标：
     *   1) 把 shelf detach 从硬删改为软删
     *   2) 保留 join 表同步字段供后续设备同步复用
     */
    _logger.info('开始软删除书架关联...');

    // 2.1 仅更新删除标记与同步相关字段
    final now = DateTime.now();
    await (update(mediaItemShelves)..where(
      (t) =>
          t.mediaItemId.equals(mediaItemId) &
          t.shelfListId.equals(shelfListId),
    )).write(
      MediaItemShelvesCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('书架关联软删除完成。');
  }

  Future<void> markLinkSynced({
    required String mediaItemId,
    required String shelfListId,
    required DateTime syncedAt,
    required String deviceId,
  }) async {
    /*
     * ========================================================================
     * 步骤3：更新书架关联的 lastSyncedAt
     * ========================================================================
     * 目标：
     *   1) 为 join 表同步成功路径记录最近同步时间
     *   2) 保持关联业务关系不被额外改写
     */
    _logger.info('开始更新书架关联的 lastSyncedAt...');

    // 3.1 仅更新同步标记字段
    await (update(mediaItemShelves)..where(
      (t) =>
          t.mediaItemId.equals(mediaItemId) &
          t.shelfListId.equals(shelfListId),
    )).write(
      MediaItemShelvesCompanion(
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('书架关联的 lastSyncedAt 更新完成。');
  }

  Stream<List<ShelfList>> watchByMediaItemId(String mediaItemId) {
    final query =
        select(shelfLists).join([
            innerJoin(
              mediaItemShelves,
              mediaItemShelves.shelfListId.equalsExp(shelfLists.id),
            ),
          ])
          ..where(mediaItemShelves.mediaItemId.equals(mediaItemId))
          ..where(mediaItemShelves.deletedAt.isNull())
          ..where(shelfLists.deletedAt.isNull());

    return query.map((row) => row.readTable(shelfLists)).watch();
  }

  Future<List<ShelfList>> getByMediaItemId(String mediaItemId) {
    final query =
        select(shelfLists).join([
            innerJoin(
              mediaItemShelves,
              mediaItemShelves.shelfListId.equalsExp(shelfLists.id),
            ),
          ])
          ..where(mediaItemShelves.mediaItemId.equals(mediaItemId))
          ..where(mediaItemShelves.deletedAt.isNull())
          ..where(shelfLists.deletedAt.isNull());

    return query.map((row) => row.readTable(shelfLists)).get();
  }

  Future<MediaItemShelve?> _findLink({
    required String mediaItemId,
    required String shelfListId,
  }) {
    return (select(mediaItemShelves)..where(
      (t) =>
          t.mediaItemId.equals(mediaItemId) &
          t.shelfListId.equals(shelfListId),
    )).getSingleOrNull();
  }
}
