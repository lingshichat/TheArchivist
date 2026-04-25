import '../../../shared/data/device_identity.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_exception.dart';
import 'sync_storage_adapter.dart';

class SyncConnectionTestResult {
  const SyncConnectionTestResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class SyncConnectionTestService {
  SyncConnectionTestService({
    required DeviceIdentityService deviceIdentityService,
    StepLogger? logger,
  }) : _deviceIdentityService = deviceIdentityService,
       _logger = logger ?? const StepLogger('SyncConnectionTestService');

  final DeviceIdentityService _deviceIdentityService;
  final StepLogger _logger;

  Future<SyncConnectionTestResult> testAdapter(
    SyncStorageAdapter adapter,
  ) async {
    /*
     * ========================================================================
     * 步骤1：执行同步目标探针测试
     * ========================================================================
     * 目标：
     *   1) 通过 write -> read -> delete 验证目标可写、可读、可清理
     *   2) 只返回脱敏摘要，不暴露凭据、签名串或原始响应体
     */
    _logger.info('开始执行同步目标探针测试...');

    // 1.1 构造当前设备专属 probe key，避免不同设备测试互相覆盖
    final deviceId = await _deviceIdentityService.getOrCreateCurrentDeviceId();
    final probeKey = '.probe/$deviceId.json';
    final probeContent =
        '{"format":"record-anywhere.sync-probe","deviceId":"$deviceId"}';

    try {
      // 1.2 写入探针对象，并立即读回确认内容一致
      await adapter.writeText(key: probeKey, content: probeContent);
      final remoteContent = await adapter.readText(probeKey);
      if (remoteContent != probeContent) {
        _logger.info('同步目标探针测试失败。');
        return const SyncConnectionTestResult(
          success: false,
          message: 'Connection test failed: probe content mismatch.',
        );
      }

      // 1.3 删除探针对象，避免连接测试留下用户可见脏对象
      await adapter.delete(probeKey);

      _logger.info('同步目标探针测试完成。');
      return const SyncConnectionTestResult(
        success: true,
        message: 'Connection test passed.',
      );
    } on SyncException catch (error) {
      // 1.4 已知同步错误只返回 typed error 摘要
      _logger.info('同步目标探针测试失败。');
      return SyncConnectionTestResult(
        success: false,
        message: _safeErrorMessage(error),
      );
    }
  }

  String _safeErrorMessage(SyncException error) {
    return switch (error) {
      SyncNetworkException() => 'Connection test failed: network unavailable.',
      SyncAuthException() => 'Connection test failed: authentication rejected.',
      SyncRemoteNotFoundException() =>
        'Connection test failed: remote path not found.',
      SyncFormatException() => 'Connection test failed: invalid remote data.',
      SyncServerException() => 'Connection test failed: remote server error.',
      SyncPartialBatchException() =>
        'Connection test failed: partial sync failure.',
    };
  }
}
