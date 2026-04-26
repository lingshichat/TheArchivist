import 'dart:convert';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/device_identity.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_codec.dart';
import 'sync_exception.dart';
import 'sync_merge_policy.dart';
import 'sync_models.dart';

class SnapshotResult {
  const SnapshotResult({
    this.appliedCount = 0,
    this.skippedCount = 0,
    this.conflictCount = 0,
    this.failedCount = 0,
    this.firstErrorSummary,
  });

  final int appliedCount;
  final int skippedCount;
  final int conflictCount;
  final int failedCount;
  final String? firstErrorSummary;

  bool get hasFailures => failedCount > 0;
}

class SnapshotService {
  SnapshotService({
    required AppDatabase database,
    required DeviceIdentityService deviceIdentityService,
    required SyncCodec codec,
    StepLogger? logger,
  }) : _database = database,
       _deviceIdentityService = deviceIdentityService,
       _codec = codec,
       _logger = logger ?? const StepLogger('SnapshotService');

  final AppDatabase _database;
  final DeviceIdentityService _deviceIdentityService;
  final SyncCodec _codec;
  final StepLogger _logger;

  static const String formatName = 'record-anywhere.snapshot';
  static const int currentVersion = 1;

  Future<String> exportSnapshot() async {
    _logger.info('开始导出快照包...');

    final deviceId = await _deviceIdentityService.getOrCreateCurrentDeviceId();
    final entities = <Map<String, Object?>>[];

    // Export in dependency order
    entities.addAll(await _encodeAllMediaItems(deviceId));
    entities.addAll(await _encodeAllTags(deviceId));
    entities.addAll(await _encodeAllShelfLists(deviceId));
    entities.addAll(await _encodeAllUserEntries(deviceId));
    entities.addAll(await _encodeAllProgressEntries(deviceId));
    entities.addAll(await _encodeAllMediaItemTags(deviceId));
    entities.addAll(await _encodeAllMediaItemShelves(deviceId));
    entities.addAll(await _encodeAllActivityLogs(deviceId));

    final snapshot = <String, Object?>{
      'format': formatName,
      'version': currentVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceId': deviceId,
      'entities': entities,
    };

    _logger.info('快照包导出完成。共 ${entities.length} 个实体。');
    return const JsonEncoder.withIndent(null).convert(snapshot);
  }

  Future<SnapshotResult> importSnapshot(String jsonContent) async {
    _logger.info('开始导入快照包...');

    Object? decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (error) {
      _logger.info('快照包导入失败：JSON 解析错误。');
      throw const SyncFormatException('Invalid snapshot: not valid JSON.');
    }

    if (decoded is! Map<Object?, Object?>) {
      throw const SyncFormatException(
        'Invalid snapshot: expected a JSON object.',
      );
    }

    final json = Map<String, Object?>.from(decoded);

    final format = json['format'];
    if (format != formatName) {
      throw const SyncFormatException(
        'Invalid snapshot: unsupported format identifier.',
      );
    }

    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw const SyncFormatException('Invalid snapshot: unsupported version.');
    }

    final rawEntities = json['entities'];
    if (rawEntities is! List) {
      throw const SyncFormatException(
        'Invalid snapshot: missing entities list.',
      );
    }

    final envelopes = <SyncEntityEnvelope>[];
    for (final rawEntity in rawEntities) {
      if (rawEntity is! Map<Object?, Object?>) continue;
      try {
        envelopes.add(
          SyncEntityEnvelope.fromJson(Map<String, Object?>.from(rawEntity)),
        );
      } catch (_) {
        continue;
      }
    }

    // Sort by dependency order for safe import
    _sortEnvelopesByDependency(envelopes);

    var appliedCount = 0;
    var skippedCount = 0;
    var conflictCount = 0;
    var failedCount = 0;
    String? firstErrorSummary;

    for (final envelope in envelopes) {
      try {
        final outcome = await _codec.applyRemoteEnvelope(envelope);
        switch (outcome.decision) {
          case SyncMergeDecision.applyRemote:
            appliedCount++;
          case SyncMergeDecision.skip:
            skippedCount++;
          case SyncMergeDecision.localWins:
            conflictCount++;
        }
      } on SyncException catch (error) {
        failedCount++;
        firstErrorSummary ??= error.message;
      } catch (error) {
        failedCount++;
        firstErrorSummary ??= 'Import failed: $error';
      }
    }

    _logger.info(
      '快照包导入完成。应用 $appliedCount，跳过 $skippedCount，冲突 $conflictCount，失败 $failedCount。',
    );

    return SnapshotResult(
      appliedCount: appliedCount,
      skippedCount: skippedCount,
      conflictCount: conflictCount,
      failedCount: failedCount,
      firstErrorSummary: firstErrorSummary,
    );
  }

  Future<List<Map<String, Object?>>> _encodeAllMediaItems(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.mediaItems).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItem,
        entityId: row.id,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'mediaType': row.mediaType.name,
          'title': row.title,
          'subtitle': row.subtitle,
          'posterUrl': row.posterUrl,
          'releaseDate': row.releaseDate?.toIso8601String(),
          'overview': row.overview,
          'sourceIdsJson': row.sourceIdsJson,
          'runtimeMinutes': row.runtimeMinutes,
          'totalEpisodes': row.totalEpisodes,
          'totalPages': row.totalPages,
          'estimatedPlayHours': row.estimatedPlayHours,
          'communityScore': row.communityScore,
          'communityRatingCount': row.communityRatingCount,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllUserEntries(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.userEntries).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.userEntry,
        entityId: row.mediaItemId,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'status': row.status.name,
          'score': row.score,
          'review': row.review,
          'notes': row.notes,
          'favorite': row.favorite,
          'reconsumeCount': row.reconsumeCount,
          'startedAt': row.startedAt?.toIso8601String(),
          'finishedAt': row.finishedAt?.toIso8601String(),
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllProgressEntries(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.progressEntries).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.progressEntry,
        entityId: row.mediaItemId,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'currentEpisode': row.currentEpisode,
          'currentPage': row.currentPage,
          'currentMinutes': row.currentMinutes,
          'completionRatio': row.completionRatio,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllTags(String deviceId) async {
    final rows = await _database.select(_database.tags).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.tag,
        entityId: row.id,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'name': row.name,
          'color': row.color,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllShelfLists(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.shelfLists).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.shelf,
        entityId: row.id,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'name': row.name,
          'kind': row.kind.name,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllMediaItemTags(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.mediaItemTags).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItemTag,
        entityId: '${row.mediaItemId}::${row.tagId}',
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'mediaItemId': row.mediaItemId,
          'tagId': row.tagId,
          'linkId': row.id,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllMediaItemShelves(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.mediaItemShelves).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItemShelf,
        entityId: '${row.mediaItemId}::${row.shelfListId}',
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'mediaItemId': row.mediaItemId,
          'shelfListId': row.shelfListId,
          'linkId': row.id,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  Future<List<Map<String, Object?>>> _encodeAllActivityLogs(
    String deviceId,
  ) async {
    final rows = await _database.select(_database.activityLogs).get();
    return rows.map((row) {
      return SyncEntityEnvelope(
        entityType: SyncEntityType.activityLog,
        entityId: row.id,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        syncVersion: row.syncVersion,
        deviceId: row.deviceId,
        lastSyncedAt: row.lastSyncedAt,
        payload: <String, Object?>{
          'mediaItemId': row.mediaItemId,
          'event': row.event.name,
          'payloadJson': row.payloadJson,
          'createdAt': row.createdAt.toIso8601String(),
        },
      ).toJson();
    }).toList();
  }

  void _sortEnvelopesByDependency(List<SyncEntityEnvelope> envelopes) {
    envelopes.sort((a, b) {
      return _entitySortOrder(
        a.entityType,
      ).compareTo(_entitySortOrder(b.entityType));
    });
  }

  int _entitySortOrder(SyncEntityType type) {
    return switch (type) {
      SyncEntityType.mediaItem => 0,
      SyncEntityType.tag => 1,
      SyncEntityType.shelf => 2,
      SyncEntityType.userEntry => 3,
      SyncEntityType.progressEntry => 4,
      SyncEntityType.mediaItemTag => 5,
      SyncEntityType.mediaItemShelf => 6,
      SyncEntityType.activityLog => 7,
    };
  }
}
