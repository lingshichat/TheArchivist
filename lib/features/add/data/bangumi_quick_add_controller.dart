import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/bangumi/data/bangumi_models.dart';
import '../../../features/bangumi/data/bangumi_sync_service.dart';
import '../../../features/bangumi/data/bangumi_type_mapper.dart';
import '../../../features/bangumi/data/providers.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/repositories/activity_log_repository.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/user_entry_repository.dart';
import '../../../shared/data/source_id_map.dart';
import '../../../shared/utils/step_logger.dart';

class BangumiQuickAddResult {
  const BangumiQuickAddResult({
    required this.mediaId,
    required this.alreadyExists,
  });

  final String mediaId;
  final bool alreadyExists;
}

final bangumiQuickAddControllerProvider = Provider<BangumiQuickAddController>((
  ref,
) {
  return BangumiQuickAddController(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    userEntryRepository: ref.watch(userEntryRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
    bangumiSyncService: ref.watch(bangumiSyncServiceProvider),
  );
});

class BangumiQuickAddController {
  BangumiQuickAddController({
    required MediaRepository mediaRepository,
    required UserEntryRepository userEntryRepository,
    required ActivityLogRepository activityLogRepository,
    required BangumiSyncService bangumiSyncService,
    StepLogger? logger,
  }) : _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _activityLogRepository = activityLogRepository,
       _bangumiSyncService = bangumiSyncService,
       _logger = logger ?? const StepLogger('BangumiQuickAddController');

  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final ActivityLogRepository _activityLogRepository;
  final BangumiSyncService _bangumiSyncService;
  final StepLogger _logger;

  Future<BangumiQuickAddResult> createFromSubject({
    required BangumiSubjectDto subject,
    required UnifiedStatus status,
  }) async {
    /*
     * ========================================================================
     * 步骤1：检查 Bangumi 条目是否已存在
     * ========================================================================
     * 目标：
     *   1) 用 `sourceIdsJson` 保证 quick add 幂等
     *   2) 已存在时直接回收本地 mediaId，不重复写库
     */
    _logger.info('开始检查 Bangumi 条目是否已存在...');

    // 1.1 读取当前 subject 的 Bangumi ID
    final bangumiId = subject.id.toString();
    final existingItem = await _mediaRepository.findBySourceId(
      'bangumi',
      bangumiId,
    );
    if (existingItem != null) {
      _logger.info('Bangumi 条目已存在检查完成。');
      return BangumiQuickAddResult(
        mediaId: existingItem.id,
        alreadyExists: true,
      );
    }

    _logger.info('Bangumi 条目已存在检查完成。');

    /*
     * ========================================================================
     * 步骤2：映射 Bangumi Subject 并写入本地库
     * ========================================================================
     * 目标：
     *   1) 把 Bangumi Subject 映射成当前本地 schema
     *   2) 先完成本地写入，再进入同步 side effect
     */
    _logger.info('开始映射 Bangumi Subject 并写入本地库...');

    // 2.1 计算本地媒体类型和基础字段
    final mediaType = BangumiTypeMapper.toMediaType(
      subject.type,
      totalEpisodes: subject.totalEpisodes,
    );
    final mediaId = await _mediaRepository.createItem(
      mediaType: mediaType,
      title: _buildTitle(subject),
      subtitle: _buildSubtitle(subject),
      posterUrl: _buildPosterUrl(subject),
      releaseDate: _parseReleaseDate(subject.date),
      overview: _normalizeOptional(subject.summary),
      sourceIdsJson: SourceIdMap.encode(<String, String>{'bangumi': bangumiId}),
      totalEpisodes: mediaType == MediaType.tv ? subject.totalEpisodes : null,
    );

    // 2.2 把默认 wishlist user entry 更新成用户选择状态
    if (status != UnifiedStatus.wishlist) {
      await _userEntryRepository.updateStatus(mediaId, status);
    }

    // 2.3 记录本地 added activity，保持详情页时间线完整
    await _activityLogRepository.appendEvent(
      mediaId,
      ActivityEvent.added,
      payload: <String, Object?>{
        'source': 'bangumi',
        'bangumiId': bangumiId,
        'title': _buildTitle(subject),
        'status': status.name,
      },
    );

    _logger.info('Bangumi Subject 本地写入完成。');

    /*
     * ========================================================================
     * 步骤3：触发注入式 Bangumi 同步 hook
     * ========================================================================
     * 目标：
     *   1) 遵守“本地优先，远程副作用后置”的 sync 合同
     *   2) 让 WP3 在不改 WP2 UI 的前提下接管远程推送
     */
    _logger.info('开始触发 Bangumi 同步 hook...');

    // 3.1 把已经落库后的 mediaId 和目标状态交给同步服务
    await _bangumiSyncService.pushCollection(
      mediaItemId: mediaId,
      status: status,
    );

    _logger.info('Bangumi 同步 hook 调用完成。');
    return BangumiQuickAddResult(mediaId: mediaId, alreadyExists: false);
  }

  String _buildTitle(BangumiSubjectDto subject) {
    final normalizedName = _normalizeOptional(subject.name);
    if (normalizedName != null) {
      return normalizedName;
    }

    return _normalizeOptional(subject.nameCn) ?? 'Bangumi #${subject.id}';
  }

  String? _buildSubtitle(BangumiSubjectDto subject) {
    final normalizedNameCn = _normalizeOptional(subject.nameCn);
    if (normalizedNameCn == null) {
      return null;
    }

    final normalizedName = _normalizeOptional(subject.name);
    if (normalizedNameCn == normalizedName) {
      return null;
    }

    return normalizedNameCn;
  }

  String? _buildPosterUrl(BangumiSubjectDto subject) {
    return _normalizeOptional(subject.images.common) ??
        _normalizeOptional(subject.images.large) ??
        _normalizeOptional(subject.images.medium) ??
        _normalizeOptional(subject.images.grid) ??
        _normalizeOptional(subject.images.small);
  }

  DateTime? _parseReleaseDate(String? rawDate) {
    final normalizedDate = _normalizeOptional(rawDate);
    if (normalizedDate == null) {
      return null;
    }

    final parts = normalizedDate.split('-');
    final year = int.tryParse(parts[0]);
    if (year == null) {
      return null;
    }

    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final day = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;

    try {
      return DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
    } on ArgumentError {
      return DateTime(year);
    }
  }

  String? _normalizeOptional(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}
