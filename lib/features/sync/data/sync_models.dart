import 'dart:convert';

enum SyncEntityType {
  mediaItem,
  userEntry,
  progressEntry,
  tag,
  shelf,
  mediaItemTag,
  mediaItemShelf,
  activityLog,
}

enum SyncOperationType { upsert, delete }

class SyncEntityEnvelope {
  const SyncEntityEnvelope({
    required this.entityType,
    required this.entityId,
    required this.updatedAt,
    required this.deviceId,
    required this.payload,
    this.deletedAt,
    this.lastSyncedAt,
    this.syncVersion = 0,
  });

  final SyncEntityType entityType;
  final String entityId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final String deviceId;
  final DateTime? lastSyncedAt;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'entityType': entityType.name,
      'entityId': entityId,
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncVersion': syncVersion,
      'deviceId': deviceId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'payload': payload,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SyncEntityEnvelope fromJson(Map<String, Object?> json) {
    return SyncEntityEnvelope(
      entityType: SyncEntityType.values.byName(json['entityType']! as String),
      entityId: json['entityId']! as String,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      deletedAt: _parseOptionalDateTime(json['deletedAt']),
      syncVersion: (json['syncVersion'] as num?)?.toInt() ?? 0,
      deviceId: json['deviceId']! as String,
      lastSyncedAt: _parseOptionalDateTime(json['lastSyncedAt']),
      payload: Map<String, Object?>.from(
        (json['payload'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
    );
  }

  static SyncEntityEnvelope fromJsonString(String jsonString) {
    return fromJson(
      Map<String, Object?>.from(jsonDecode(jsonString) as Map<Object?, Object?>),
    );
  }

  static DateTime? _parseOptionalDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }
}

class SyncChangeCandidate {
  const SyncChangeCandidate({
    required this.entityType,
    required this.entityId,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
    this.lastSyncedAt,
  });

  final SyncEntityType entityType;
  final String entityId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final DateTime? lastSyncedAt;

  bool get needsSync {
    if (deletedAt != null) {
      return true;
    }

    if (lastSyncedAt == null) {
      return true;
    }

    return updatedAt.isAfter(lastSyncedAt!);
  }
}
