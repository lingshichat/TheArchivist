import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../shared/utils/step_logger.dart';
import 'sync_target_config.dart';

abstract interface class SyncTargetStore {
  Future<SyncTargetConfig> read();

  Future<void> write(SyncTargetConfig config);

  Future<void> clear();
}

class SecureSyncTargetStore implements SyncTargetStore {
  SecureSyncTargetStore({
    FlutterSecureStorage? secureStorage,
    StepLogger? logger,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _logger = logger ?? const StepLogger('SecureSyncTargetStore');

  static const String _configKey = 'sync_target_config_v1';

  final FlutterSecureStorage _secureStorage;
  final StepLogger _logger;

  @override
  Future<SyncTargetConfig> read() async {
    /*
     * ========================================================================
     * 步骤1：读取同步目标配置
     * ========================================================================
     * 目标：
     *   1) 从 secure storage 读取 WebDAV / S3-compatible 配置
     *   2) 只返回归一化后的配置对象，不向调用方暴露原始 JSON
     */
    _logger.info('开始读取同步目标配置...');

    // 1.1 读取加密存储中的配置 JSON；缺失时返回空配置
    final rawConfig = await _secureStorage.read(key: _configKey);
    if (rawConfig == null || rawConfig.trim().isEmpty) {
      _logger.info('同步目标配置读取完成。');
      return const SyncTargetConfig();
    }

    // 1.2 解析配置 JSON，并转换成类型化配置对象
    final decoded = jsonDecode(rawConfig);
    final config = SyncTargetConfig.fromJson(
      Map<String, Object?>.from(decoded as Map<Object?, Object?>),
    );

    _logger.info('同步目标配置读取完成。');
    return config;
  }

  @override
  Future<void> write(SyncTargetConfig config) async {
    /*
     * ========================================================================
     * 步骤2：写入同步目标配置
     * ========================================================================
     * 目标：
     *   1) 把类型化同步配置序列化后写入 secure storage
     *   2) 避免凭据进入普通数据库、activity log 或控制台输出
     */
    _logger.info('开始写入同步目标配置...');

    // 2.1 序列化完整配置；敏感字段只保存在 secure storage
    final encodedConfig = jsonEncode(config.toJson());

    // 2.2 写入 secure storage，供后续连接测试和手动同步复用
    await _secureStorage.write(key: _configKey, value: encodedConfig);

    _logger.info('同步目标配置写入完成。');
  }

  @override
  Future<void> clear() async {
    /*
     * ========================================================================
     * 步骤3：清理同步目标配置
     * ========================================================================
     * 目标：
     *   1) 删除本地保存的同步目标和凭据
     *   2) 为断开连接或测试重置提供统一入口
     */
    _logger.info('开始清理同步目标配置...');

    // 3.1 删除 secure storage 中的同步目标配置
    await _secureStorage.delete(key: _configKey);

    _logger.info('同步目标配置清理完成。');
  }
}

class InMemorySyncTargetStore implements SyncTargetStore {
  InMemorySyncTargetStore({SyncTargetConfig? config})
    : _config = config ?? const SyncTargetConfig();

  SyncTargetConfig _config;

  @override
  Future<SyncTargetConfig> read() async {
    return _config;
  }

  @override
  Future<void> write(SyncTargetConfig config) async {
    _config = config;
  }

  @override
  Future<void> clear() async {
    _config = const SyncTargetConfig();
  }
}
