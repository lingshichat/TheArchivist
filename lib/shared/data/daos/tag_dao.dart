import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/media_item_tags.dart';
import '../tables/tags.dart';
import '../../utils/step_logger.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, MediaItemTags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  static const StepLogger _logger = StepLogger('TagDao');

  Stream<List<Tag>> watchAll() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).watch();
  }

  Future<List<Tag>> getAll() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<void> upsert(TagsCompanion tag) {
    return into(tags).insertOnConflictUpdate(tag);
  }

  Future<void> attach(
    String mediaItemId,
    String tagId,
    String id,
    String deviceId,
  ) {
    final now = DateTime.now();
    into(mediaItemTags).insert(
      MediaItemTagsCompanion.insert(
        id: id,
        mediaItemId: mediaItemId,
        tagId: tagId,
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );
    return Future.value();
  }

  Future<void> detach(String mediaItemId, String tagId, String deviceId) {
    return softDetach(
      mediaItemId: mediaItemId,
      tagId: tagId,
      deviceId: deviceId,
      updatedAt: DateTime.now(),
      syncedAt: null,
    );
  }

  Future<void> attachOrRestore({
    required String mediaItemId,
    required String tagId,
    required String id,
    required String deviceId,
    required DateTime updatedAt,
    required DateTime? syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：补写或恢复标签关联
     * ========================================================================
     * 目标：
     *   1) 让 join 表在 attach 时优先复用已存在记录
     *   2) 保持 deletedAt / lastSyncedAt / deviceId 语义一致
     */
    _logger.info('开始补写或恢复标签关联...');

    // 1.1 先查是否已有同 mediaItem/tag 的 join 行
    final existing = await _findLink(mediaItemId: mediaItemId, tagId: tagId);
    if (existing == null) {
      // 1.2 不存在时直接插入新关联
      await into(mediaItemTags).insert(
        MediaItemTagsCompanion.insert(
          id: id,
          mediaItemId: mediaItemId,
          tagId: tagId,
          createdAt: updatedAt,
          updatedAt: updatedAt,
          deletedAt: const Value(null),
          deviceId: Value(deviceId),
          lastSyncedAt: Value(syncedAt),
        ),
      );
      _logger.info('标签关联补写或恢复完成。');
      return;
    }

    // 1.3 已存在时恢复软删并刷新同步字段
    await (update(mediaItemTags)..where((t) => t.id.equals(existing.id))).write(
      MediaItemTagsCompanion(
        updatedAt: Value(updatedAt),
        deletedAt: const Value(null),
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('标签关联补写或恢复完成。');
  }

  Future<void> softDetach({
    required String mediaItemId,
    required String tagId,
    required String deviceId,
    required DateTime updatedAt,
    required DateTime? syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：软删除标签关联
     * ========================================================================
     * 目标：
     *   1) 把 tag detach 从硬删改为软删
     *   2) 保留 join 表同步字段供后续设备同步复用
     */
    _logger.info('开始软删除标签关联...');

    // 2.1 仅更新删除标记与同步相关字段
    await (update(mediaItemTags)..where(
          (t) => t.mediaItemId.equals(mediaItemId) & t.tagId.equals(tagId),
        ))
        .write(
          MediaItemTagsCompanion(
            updatedAt: Value(updatedAt),
            deletedAt: Value(updatedAt),
            deviceId: Value(deviceId),
            lastSyncedAt: Value(syncedAt),
          ),
        );

    _logger.info('标签关联软删除完成。');
  }

  Future<void> markLinkSynced({
    required String mediaItemId,
    required String tagId,
    required DateTime syncedAt,
    required String deviceId,
  }) async {
    /*
     * ========================================================================
     * 步骤3：更新标签关联的 lastSyncedAt
     * ========================================================================
     * 目标：
     *   1) 为 join 表同步成功路径记录最近同步时间
     *   2) 保持关联业务关系不被额外改写
     */
    _logger.info('开始更新标签关联的 lastSyncedAt...');

    // 3.1 仅更新同步标记字段
    await (update(mediaItemTags)..where(
          (t) => t.mediaItemId.equals(mediaItemId) & t.tagId.equals(tagId),
        ))
        .write(
          MediaItemTagsCompanion(
            deviceId: Value(deviceId),
            lastSyncedAt: Value(syncedAt),
          ),
        );

    _logger.info('标签关联的 lastSyncedAt 更新完成。');
  }

  Stream<List<Tag>> watchByMediaItemId(String mediaItemId) {
    final query =
        select(tags).join([
            innerJoin(mediaItemTags, mediaItemTags.tagId.equalsExp(tags.id)),
          ])
          ..where(mediaItemTags.mediaItemId.equals(mediaItemId))
          ..where(mediaItemTags.deletedAt.isNull())
          ..where(tags.deletedAt.isNull());

    return query.map((row) => row.readTable(tags)).watch();
  }

  Future<List<Tag>> getByMediaItemId(String mediaItemId) {
    final query =
        select(tags).join([
            innerJoin(mediaItemTags, mediaItemTags.tagId.equalsExp(tags.id)),
          ])
          ..where(mediaItemTags.mediaItemId.equals(mediaItemId))
          ..where(mediaItemTags.deletedAt.isNull())
          ..where(tags.deletedAt.isNull());

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<MediaItemTag?> _findLink({
    required String mediaItemId,
    required String tagId,
  }) {
    return (select(mediaItemTags)..where(
          (t) => t.mediaItemId.equals(mediaItemId) & t.tagId.equals(tagId),
        ))
        .getSingleOrNull();
  }
}
