class BangumiSearchResult {
  const BangumiSearchResult({
    required this.total,
    required this.data,
    required this.limit,
    required this.offset,
  });

  factory BangumiSearchResult.fromJson(Map<String, Object?> json) {
    return BangumiSearchResult(
      total: _asInt(json['total']) ?? 0,
      data: _asList(
        json['data'],
      ).map(BangumiSubjectDto.fromJson).toList(growable: false),
      limit: _asInt(json['limit']) ?? 0,
      offset: _asInt(json['offset']) ?? 0,
    );
  }

  final int total;
  final List<BangumiSubjectDto> data;
  final int limit;
  final int offset;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'total': total,
      'data': data.map((item) => item.toJson()).toList(growable: false),
      'limit': limit,
      'offset': offset,
    };
  }
}

class BangumiSubjectDto {
  const BangumiSubjectDto({
    required this.id,
    required this.type,
    required this.name,
    this.nameCn,
    this.summary,
    this.date,
    this.images = const BangumiImages.empty(),
    this.rating,
    this.eps,
    this.totalEpisodes,
  });

  factory BangumiSubjectDto.fromJson(Map<String, Object?> json) {
    return BangumiSubjectDto(
      id: _asInt(json['id']) ?? 0,
      type: _asInt(json['type']) ?? 0,
      name: _asString(json['name']) ?? '',
      nameCn: _asNullableTrimmedString(json['name_cn']),
      summary: _asNullableTrimmedString(json['summary']),
      date: _asNullableTrimmedString(json['date']),
      images: BangumiImages.fromJson(
        _asMap(json['images']) ??
            _asMap(json['image']) ??
            const <String, Object?>{},
      ),
      rating: _asMap(json['rating']) == null
          ? null
          : BangumiRatingDto.fromJson(_asMap(json['rating'])!),
      eps: _asInt(json['eps']),
      totalEpisodes: _asInt(json['total_episodes']) ?? _asInt(json['eps']),
    );
  }

  final int id;
  final int type;
  final String name;
  final String? nameCn;
  final String? summary;
  final String? date;
  final BangumiImages images;
  final BangumiRatingDto? rating;
  final int? eps;
  final int? totalEpisodes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type,
      'name': name,
      'name_cn': nameCn,
      'summary': summary,
      'date': date,
      'images': images.toJson(),
      'rating': rating?.toJson(),
      'eps': eps,
      'total_episodes': totalEpisodes,
    };
  }
}

class BangumiImages {
  const BangumiImages({
    this.small,
    this.grid,
    this.large,
    this.medium,
    this.common,
  });

  const BangumiImages.empty()
    : small = null,
      grid = null,
      large = null,
      medium = null,
      common = null;

  factory BangumiImages.fromJson(Map<String, Object?> json) {
    return BangumiImages(
      small: _asNullableTrimmedString(json['small']),
      grid: _asNullableTrimmedString(json['grid']),
      large: _asNullableTrimmedString(json['large']),
      medium: _asNullableTrimmedString(json['medium']),
      common: _asNullableTrimmedString(json['common']),
    );
  }

  final String? small;
  final String? grid;
  final String? large;
  final String? medium;
  final String? common;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'small': small,
      'grid': grid,
      'large': large,
      'medium': medium,
      'common': common,
    };
  }
}

class BangumiRatingDto {
  const BangumiRatingDto({
    this.rank,
    this.total,
    this.score,
    this.count = const <String, int>{},
  });

  factory BangumiRatingDto.fromJson(Map<String, Object?> json) {
    final rawCount = _asMap(json['count']) ?? const <String, Object?>{};

    return BangumiRatingDto(
      rank: _asInt(json['rank']),
      total: _asInt(json['total']),
      score: _asDouble(json['score']),
      count: rawCount.map((key, value) => MapEntry(key, _asInt(value) ?? 0)),
    );
  }

  final int? rank;
  final int? total;
  final double? score;
  final Map<String, int> count;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rank': rank,
      'total': total,
      'score': score,
      'count': count,
    };
  }
}

class BangumiUserDto {
  const BangumiUserDto({
    required this.id,
    this.username,
    this.nickname,
    this.sign,
    this.avatar,
  });

  factory BangumiUserDto.fromJson(Map<String, Object?> json) {
    final avatarMap = _asMap(json['avatar']);

    return BangumiUserDto(
      id: _asInt(json['id']) ?? 0,
      username:
          _asNullableTrimmedString(json['username']) ??
          _asNullableTrimmedString(json['user_id']),
      nickname:
          _asNullableTrimmedString(json['nickname']) ??
          _asNullableTrimmedString(json['display_name']),
      sign: _asNullableTrimmedString(json['sign']),
      avatar: avatarMap == null ? null : BangumiImages.fromJson(avatarMap),
    );
  }

  final int id;
  final String? username;
  final String? nickname;
  final String? sign;
  final BangumiImages? avatar;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'username': username,
      'nickname': nickname,
      'sign': sign,
      'avatar': avatar?.toJson(),
    };
  }
}

class BangumiCollectionDto {
  const BangumiCollectionDto({
    required this.subjectId,
    this.type,
    this.rate,
    this.comment,
    this.isPrivate,
    this.tags = const <String>[],
    this.updatedAt,
    this.subject,
  });

  factory BangumiCollectionDto.fromJson(Map<String, Object?> json) {
    final subjectMap = _asMap(json['subject']);

    return BangumiCollectionDto(
      subjectId:
          _asInt(json['subject_id']) ??
          _asInt(json['subjectId']) ??
          _asInt(subjectMap?['id']) ??
          0,
      type: _asInt(json['type']),
      rate: _asInt(json['rate']),
      comment: _asNullableTrimmedString(json['comment']),
      isPrivate: _asBool(json['private']),
      tags: _asDynamicList(json['tags'])
          .map(_asNullableTrimmedString)
          .whereType<String>()
          .toList(growable: false),
      updatedAt:
          _asNullableTrimmedString(json['updated_at']) ??
          _asNullableTrimmedString(json['updatedAt']),
      subject: subjectMap == null
          ? null
          : BangumiSubjectDto.fromJson(subjectMap),
    );
  }

  final int subjectId;
  final int? type;
  final int? rate;
  final String? comment;
  final bool? isPrivate;
  final List<String> tags;
  final String? updatedAt;
  final BangumiSubjectDto? subject;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'subject_id': subjectId,
      'type': type,
      'rate': rate,
      'comment': comment,
      'private': isPrivate,
      'tags': tags,
      'updated_at': updatedAt,
      'subject': subject?.toJson(),
    };
  }
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  return null;
}

List<Map<String, Object?>> _asList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }

  return value
      .map(_asMap)
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
}

List<Object?> _asDynamicList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }

  if (value is List) {
    return value.cast<Object?>();
  }

  return const <Object?>[];
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }

  return null;
}

String? _asString(Object? value) {
  if (value is String) {
    return value;
  }

  return value?.toString();
}

String? _asNullableTrimmedString(Object? value) {
  final normalized = _asString(value)?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
