import 'package:drift/drift.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/sync_stamp.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_models.dart';

class SyncConflictCopy {
  const SyncConflictCopy({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.detectedAt,
    required this.resolved,
    this.localValue,
    this.remoteValue,
    this.localDeviceId,
    this.remoteDeviceId,
    this.resolvedAt,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final String fieldName;
  final String? localValue;
  final String? remoteValue;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final String? localDeviceId;
  final String? remoteDeviceId;
  final DateTime detectedAt;
  final bool resolved;
  final DateTime? resolvedAt;
}

class SyncConflictRepository {
  SyncConflictRepository({required AppDatabase database, StepLogger? logger})
    : _database = database,
      _logger = logger ?? const StepLogger('SyncConflictRepository');

  final AppDatabase _database;
  final StepLogger _logger;

  Future<void> recordTextConflict({
    required SyncEntityType entityType,
    required String entityId,
    required String fieldName,
    required String? localValue,
    required String? remoteValue,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required String? localDeviceId,
    required String? remoteDeviceId,
  }) async {
    /*
     * ========================================================================
     * Step 1: Preserve a text-field conflict copy
     * ========================================================================
     * Goal:
     *   1) Keep the overwritten side of notes/review conflicts recoverable.
     *   2) Store a small audit row without changing the phase-3 merge UI scope.
     */
    _logger.info('Recording sync text conflict copy...');

    if (localValue == remoteValue) {
      _logger.info('Sync text conflict copy skipped: values match.');
      return;
    }

    await _database.customInsert(
      '''
        INSERT INTO sync_conflict_entries (
          id,
          entity_type,
          entity_id,
          field_name,
          local_value,
          remote_value,
          local_updated_at,
          remote_updated_at,
          local_device_id,
          remote_device_id,
          detected_at,
          resolved,
          resolved_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL)
        ON CONFLICT(id) DO UPDATE SET
          local_value = excluded.local_value,
          remote_value = excluded.remote_value,
          detected_at = excluded.detected_at,
          resolved = 0,
          resolved_at = NULL
      ''',
      variables: [
        Variable<String>(
          _buildConflictId(
            entityType: entityType,
            entityId: entityId,
            fieldName: fieldName,
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeviceId: remoteDeviceId,
          ),
        ),
        Variable<String>(entityType.name),
        Variable<String>(entityId),
        Variable<String>(fieldName),
        Variable<String>(localValue),
        Variable<String>(remoteValue),
        Variable<String>(localUpdatedAt.toIso8601String()),
        Variable<String>(remoteUpdatedAt.toIso8601String()),
        Variable<String>(localDeviceId),
        Variable<String>(remoteDeviceId),
        Variable<String>(SyncStampDecorator.now().toIso8601String()),
      ],
    );

    _logger.info('Sync text conflict copy recorded.');
  }

  Future<List<SyncConflictCopy>> listPending() async {
    final rows = await _database.customSelect(
      '''
        SELECT *
        FROM sync_conflict_entries
        WHERE resolved = 0
        ORDER BY detected_at DESC
      ''',
    ).get();
    return rows.map(_mapRow).toList();
  }

  String _buildConflictId({
    required SyncEntityType entityType,
    required String entityId,
    required String fieldName,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required String? remoteDeviceId,
  }) {
    final safeEntityId = Uri.encodeComponent(entityId);
    final safeRemoteDeviceId = Uri.encodeComponent(remoteDeviceId ?? '');
    return [
      entityType.name,
      safeEntityId,
      fieldName,
      localUpdatedAt.microsecondsSinceEpoch,
      remoteUpdatedAt.microsecondsSinceEpoch,
      safeRemoteDeviceId,
    ].join('|');
  }

  SyncConflictCopy _mapRow(QueryRow row) {
    return SyncConflictCopy(
      id: row.read<String>('id'),
      entityType: SyncEntityType.values.byName(row.read<String>('entity_type')),
      entityId: row.read<String>('entity_id'),
      fieldName: row.read<String>('field_name'),
      localValue: row.readNullable<String>('local_value'),
      remoteValue: row.readNullable<String>('remote_value'),
      localUpdatedAt: _readDateTime(row, 'local_updated_at'),
      remoteUpdatedAt: _readDateTime(row, 'remote_updated_at'),
      localDeviceId: row.readNullable<String>('local_device_id'),
      remoteDeviceId: row.readNullable<String>('remote_device_id'),
      detectedAt: _readDateTime(row, 'detected_at'),
      resolved: row.read<int>('resolved') != 0,
      resolvedAt: _readNullableDateTime(row, 'resolved_at'),
    );
  }

  DateTime _readDateTime(QueryRow row, String columnName) {
    return DateTime.parse(row.read<String>(columnName));
  }

  DateTime? _readNullableDateTime(QueryRow row, String columnName) {
    final value = row.readNullable<String>(columnName);
    if (value == null) {
      return null;
    }
    return DateTime.parse(value);
  }
}
