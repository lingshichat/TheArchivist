import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../utils/step_logger.dart';

abstract interface class DeviceIdentityStore {
  Future<String?> read();

  Future<void> write(String deviceId);

  Future<void> clear();
}

class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore({
    FlutterSecureStorage? secureStorage,
    StepLogger? logger,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _logger = logger ?? const StepLogger('SecureDeviceIdentityStore');

  static const String _deviceIdKey = 'current_device_id';

  final FlutterSecureStorage _secureStorage;
  final StepLogger _logger;

  @override
  Future<String?> read() async {
    /*
     * ========================================================================
     * 步骤1：读取当前设备身份
     * ========================================================================
     * 目标：
     *   1) 从 secure storage 取出当前设备 ID
     *   2) 统一把空白值归一化为 null
     */
    _logger.info('开始读取当前设备身份...');

    // 1.1 读取本地持久化的设备 ID
    final rawDeviceId = await _secureStorage.read(key: _deviceIdKey);

    // 1.2 归一化空白值，避免把脏数据继续向上游传播
    final normalizedDeviceId = _normalizeOptional(rawDeviceId);

    _logger.info('当前设备身份读取完成。');
    return normalizedDeviceId;
  }

  @override
  Future<void> write(String deviceId) async {
    /*
     * ========================================================================
     * 步骤2：写入当前设备身份
     * ========================================================================
     * 目标：
     *   1) 统一当前设备 ID 的持久化入口
     *   2) 拒绝把空白 deviceId 写入本地存储
     */
    _logger.info('开始写入当前设备身份...');

    // 2.1 归一化待写入的设备 ID，并拒绝空值
    final normalizedDeviceId = _normalizeOptional(deviceId);
    if (normalizedDeviceId == null) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'Device ID cannot be empty.',
      );
    }

    // 2.2 将设备 ID 落盘到 secure storage
    await _secureStorage.write(key: _deviceIdKey, value: normalizedDeviceId);

    _logger.info('当前设备身份写入完成。');
  }

  @override
  Future<void> clear() async {
    /*
     * ========================================================================
     * 步骤3：清理当前设备身份
     * ========================================================================
     * 目标：
     *   1) 为测试或极端重置场景提供统一清理入口
     *   2) 保持存储状态与调用方预期一致
     */
    _logger.info('开始清理当前设备身份...');

    // 3.1 删除当前设备 ID 持久化记录
    await _secureStorage.delete(key: _deviceIdKey);

    _logger.info('当前设备身份清理完成。');
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class InMemoryDeviceIdentityStore implements DeviceIdentityStore {
  InMemoryDeviceIdentityStore({String? deviceId})
    : _deviceId = _normalizeOptional(deviceId);

  String? _deviceId;

  @override
  Future<String?> read() async {
    return _deviceId;
  }

  @override
  Future<void> write(String deviceId) async {
    final normalizedDeviceId = _normalizeOptional(deviceId);
    if (normalizedDeviceId == null) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'Device ID cannot be empty.',
      );
    }

    _deviceId = normalizedDeviceId;
  }

  @override
  Future<void> clear() async {
    _deviceId = null;
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class DeviceIdentityService {
  DeviceIdentityService({DeviceIdentityStore? store, StepLogger? logger})
    : _store = store ?? SecureDeviceIdentityStore(),
      _logger = logger ?? const StepLogger('DeviceIdentityService');

  static const Uuid _uuid = Uuid();

  final DeviceIdentityStore _store;
  final StepLogger _logger;

  static String generate() => _uuid.v4();

  Future<String?> readCurrentDeviceId() {
    return _store.read();
  }

  Future<void> writeCurrentDeviceId(String deviceId) async {
    final normalizedDeviceId = _normalizeRequired(deviceId);
    await _store.write(normalizedDeviceId);
  }

  Future<String> getOrCreateCurrentDeviceId() async {
    /*
     * ========================================================================
     * 步骤1：获取当前设备身份
     * ========================================================================
     * 目标：
     *   1) 优先复用已持久化的当前设备 ID
     *   2) 缺失时生成并落盘稳定 deviceId
     */
    _logger.info('开始获取当前设备身份...');

    // 1.1 先读取已有设备 ID；命中时直接复用
    final existingDeviceId = await _store.read();
    if (existingDeviceId != null) {
      _logger.info('当前设备身份获取完成。');
      return existingDeviceId;
    }

    // 1.2 缺失时生成新设备 ID，并立即持久化
    final nextDeviceId = generate();
    await _store.write(nextDeviceId);

    _logger.info('当前设备身份获取完成。');
    return nextDeviceId;
  }

  String _normalizeRequired(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'deviceId',
        'Device ID cannot be empty.',
      );
    }
    return normalized;
  }
}
