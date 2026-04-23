import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';
import '../../utils/step_logger.dart';

class TagRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;
  static const StepLogger _logger = StepLogger('TagRepository');

  TagRepository(this._db, {DeviceIdentityService? deviceIdentityService})
    : _deviceIdentityService =
          deviceIdentityService ?? DeviceIdentityService();

  Stream<List<Tag>> watchAll() => _db.tagDao.watchAll();

  Stream<List<Tag>> watchByMediaItemId(String mediaItemId) {
    return _db.tagDao.watchByMediaItemId(mediaItemId);
  }

  Future<List<Tag>> getByMediaItemId(String mediaItemId) {
    return _db.tagDao.getByMediaItemId(mediaItemId);
  }

  Future<String> createTag({required String name, String? color}) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.tagDao.upsert(
      TagsCompanion.insert(
        id: id,
        name: name,
        color: Value(color),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

    return id;
  }

  Future<void> attachToMedia(String mediaItemId, String tagId) async {
    final deviceId = await _getDeviceId();
    await _db.tagDao.attachOrRestore(
      mediaItemId: mediaItemId,
      tagId: tagId,
      id: DeviceIdentityService.generate(),
      deviceId: deviceId,
      syncedAt: null,
    );
  }

  Future<void> detachFromMedia(String mediaItemId, String tagId) async {
    final deviceId = await _getDeviceId();
    await _db.tagDao.detach(mediaItemId, tagId, deviceId);
  }

  Future<void> syncTagsForMedia(
    String mediaItemId,
    Iterable<String> rawNames,
  ) async {
    final desiredNames = _normalizeNames(rawNames);
    final existingTags = await _db.tagDao.getAll();
    final currentTags = await _db.tagDao.getByMediaItemId(mediaItemId);

    final existingByName = <String, Tag>{
      for (final tag in existingTags) tag.name.toLowerCase(): tag,
    };
    final currentIds = currentTags.map((e) => e.id).toSet();
    final desiredIds = <String>{};

    for (final name in desiredNames) {
      final key = name.toLowerCase();
      final existing = existingByName[key];
      final tagId = existing?.id ?? await createTag(name: name);
      desiredIds.add(tagId);

      if (!currentIds.contains(tagId)) {
        await attachToMedia(mediaItemId, tagId);
      }
    }

    for (final tag in currentTags) {
      if (!desiredIds.contains(tag.id)) {
        await detachFromMedia(mediaItemId, tag.id);
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
    required String tagId,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤1：应用远端回拉得到的标签关联
     * ========================================================================
     * 目标：
     *   1) 为后续 sync engine 提供统一的 tag attach 写回入口
     *   2) 保证 join 表记录具备同步字段
     */
    _logger.info('开始应用远端回拉标签关联...');

    // 1.1 读取当前设备 ID，并用 sync-aware 方式补写关联
    final deviceId = await _getDeviceId();
    await _db.tagDao.attachOrRestore(
      mediaItemId: mediaItemId,
      tagId: tagId,
      id: DeviceIdentityService.generate(),
      deviceId: deviceId,
      syncedAt: syncedAt,
    );

    _logger.info('远端回拉标签关联应用完成。');
  }

  Future<void> applyRemoteDetachment({
    required String mediaItemId,
    required String tagId,
    required DateTime syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：应用远端回拉得到的标签解绑
     * ========================================================================
     * 目标：
     *   1) 为后续 sync engine 提供统一的 tag detach 写回入口
     *   2) 统一走软删除而不是直接硬删
     */
    _logger.info('开始应用远端回拉标签解绑...');

    // 2.1 仅更新 join 表删除标记，保留同步字段语义
    final deviceId = await _getDeviceId();
    await _db.tagDao.softDetach(
      mediaItemId: mediaItemId,
      tagId: tagId,
      deviceId: deviceId,
      syncedAt: syncedAt,
    );

    _logger.info('远端回拉标签解绑应用完成。');
  }

  Future<void> markTagLinkSynced(
    String mediaItemId,
    String tagId,
    DateTime syncedAt,
  ) async {
    /*
     * ========================================================================
     * 步骤3：标记标签关联最近一次同步时间
     * ========================================================================
     * 目标：
     *   1) 为 push / pull 成功路径补写 join 表同步戳
     *   2) 保持关联业务关系不被额外改写
     */
    _logger.info('开始标记标签关联同步时间...');

    // 3.1 仅更新 join 表同步标记字段
    final deviceId = await _getDeviceId();
    await _db.tagDao.markLinkSynced(
      mediaItemId: mediaItemId,
      tagId: tagId,
      syncedAt: syncedAt,
      deviceId: deviceId,
    );

    _logger.info('标签关联同步时间标记完成。');
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
