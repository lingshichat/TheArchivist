import '../../../shared/data/app_database.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_models.dart';
import 'bangumi_type_mapper.dart';

class BangumiLocalMediaDraft {
  const BangumiLocalMediaDraft({
    required this.mediaType,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.releaseDate,
    this.overview,
    this.runtimeMinutes,
    this.totalEpisodes,
    this.totalPages,
    this.estimatedPlayHours,
    this.tags = const <String>[],
    this.communityScore,
    this.communityRatingCount,
  });

  final MediaType mediaType;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final DateTime? releaseDate;
  final String? overview;
  final int? runtimeMinutes;
  final int? totalEpisodes;
  final int? totalPages;
  final double? estimatedPlayHours;
  final List<String> tags;
  final double? communityScore;
  final int? communityRatingCount;
}

abstract final class BangumiSubjectMapper {
  static const StepLogger _logger = StepLogger('BangumiSubjectMapper');

  static BangumiLocalMediaDraft toLocalMediaDraft(BangumiSubjectDto subject) {
    /*
     * ========================================================================
     * 步骤1：把 Bangumi Subject 映射成本地媒体草稿
     * ========================================================================
     * 目标：
     *   1) 让 Quick Add 和批量 pull 复用同一份字段映射逻辑
     *   2) 统一标题、副标题、封面、日期等基础字段的归一化规则
     */
    _logger.info('开始映射 Bangumi Subject 到本地媒体草稿...');

    // 1.1 先根据 subject type 推导本地媒体类型
    final mediaType = BangumiTypeMapper.toMediaType(
      subject.type,
      totalEpisodes: subject.totalEpisodes,
    );

    // 1.2 组合本地创建条目需要的基础字段
    final draft = BangumiLocalMediaDraft(
      mediaType: mediaType,
      title: _buildTitle(subject),
      subtitle: _buildSubtitle(subject),
      posterUrl: _buildPosterUrl(subject),
      releaseDate: _parseReleaseDate(subject.date),
      overview: _normalizeOptional(subject.summary),
      totalEpisodes: mediaType == MediaType.tv ? subject.totalEpisodes : null,
      tags: _normalizeTags(subject.tags),
      communityScore: subject.rating?.score,
      communityRatingCount: subject.rating?.total,
    );

    _logger.info('Bangumi Subject 到本地媒体草稿映射完成。');
    return draft;
  }

  static String _buildTitle(BangumiSubjectDto subject) {
    final normalizedName = _normalizeOptional(subject.name);
    if (normalizedName != null) {
      return normalizedName;
    }

    return _normalizeOptional(subject.nameCn) ?? 'Bangumi #${subject.id}';
  }

  static String? _buildSubtitle(BangumiSubjectDto subject) {
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

  static String? _buildPosterUrl(BangumiSubjectDto subject) {
    return _normalizeOptional(subject.images.common) ??
        _normalizeOptional(subject.images.large) ??
        _normalizeOptional(subject.images.medium) ??
        _normalizeOptional(subject.images.grid) ??
        _normalizeOptional(subject.images.small);
  }

  static DateTime? _parseReleaseDate(String? rawDate) {
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

  static String? _normalizeOptional(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }

  static List<String> _normalizeTags(List<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final tag = _normalizeOptional(value);
      if (tag == null) {
        continue;
      }

      final key = tag.toLowerCase();
      if (seen.add(key)) {
        normalized.add(tag);
      }
    }
    return normalized;
  }
}
