import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class ActivityLogRepository {
  final AppDatabase _db;
  final DeviceIdentityService _deviceIdentityService;

  ActivityLogRepository(
    this._db, {
    DeviceIdentityService? deviceIdentityService,
  }) : _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();

  Stream<List<ActivityLog>> watchByMediaItemId(String mediaItemId) {
    return _db.activityLogDao.watchByMediaItemId(mediaItemId);
  }

  Future<void> appendEvent(
    String mediaItemId,
    ActivityEvent event, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final now = SyncStampDecorator.now();
    final deviceId = await _getDeviceId();

    await _db.activityLogDao.insertLog(
      ActivityLogsCompanion.insert(
        id: DeviceIdentityService.generate(),
        mediaItemId: mediaItemId,
        event: event,
        payloadJson: Value(jsonEncode(payload)),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<String> _getDeviceId() async {
    return _deviceIdentityService.getOrCreateCurrentDeviceId();
  }
}
