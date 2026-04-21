import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../shared/utils/step_logger.dart';

abstract class BangumiTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class SecureBangumiTokenStore implements BangumiTokenStore {
  SecureBangumiTokenStore({
    FlutterSecureStorage? secureStorage,
    StepLogger? logger,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _logger = logger ?? const StepLogger('SecureBangumiTokenStore');

  static const String _tokenKey = 'bangumi_access_token';

  final FlutterSecureStorage _secureStorage;
  final StepLogger _logger;

  @override
  Future<String?> read() async {
    /*
     * ========================================================================
     * 步骤1：读取本地 Bangumi Access Token
     * ========================================================================
     * 目标：
     *   1) 为认证恢复和网络层 header 注入提供统一读取入口
     *   2) 确保空白 token 不会继续向上游传播
     */
    _logger.info('开始读取本地 Bangumi Access Token...');

    // 1.1 从 secure storage 中读取原始 token
    final rawToken = await _secureStorage.read(key: _tokenKey);

    // 1.2 归一化空白值，统一返回 null
    final normalizedToken = _normalizeOptional(rawToken);

    _logger.info('本地 Bangumi Access Token 读取完成。');
    return normalizedToken;
  }

  @override
  Future<void> write(String token) async {
    /*
     * ========================================================================
     * 步骤2：写入本地 Bangumi Access Token
     * ========================================================================
     * 目标：
     *   1) 统一 secure storage 落盘行为
     *   2) 防止未归一化 token 被直接写入
     */
    _logger.info('开始写入本地 Bangumi Access Token...');

    // 2.1 归一化待写入 token，并拒绝空字符串
    final normalizedToken = _normalizeOptional(token);
    if (normalizedToken == null) {
      throw ArgumentError.value(
        token,
        'token',
        'Bangumi token cannot be empty.',
      );
    }

    // 2.2 将验证通过的 token 写入 secure storage
    await _secureStorage.write(key: _tokenKey, value: normalizedToken);

    _logger.info('本地 Bangumi Access Token 写入完成。');
  }

  @override
  Future<void> clear() async {
    /*
     * ========================================================================
     * 步骤3：清理本地 Bangumi Access Token
     * ========================================================================
     * 目标：
     *   1) 在断开连接和 token 失效时统一移除本地凭据
     *   2) 保持认证状态与存储状态一致
     */
    _logger.info('开始清理本地 Bangumi Access Token...');

    // 3.1 删除 secure storage 中的 Bangumi token
    await _secureStorage.delete(key: _tokenKey);

    _logger.info('本地 Bangumi Access Token 清理完成。');
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class InMemoryBangumiTokenStore implements BangumiTokenStore {
  InMemoryBangumiTokenStore({String? token})
    : _token = _normalizeOptional(token);

  String? _token;

  @override
  Future<String?> read() async {
    return _token;
  }

  @override
  Future<void> write(String token) async {
    final normalizedToken = _normalizeOptional(token);
    if (normalizedToken == null) {
      throw ArgumentError.value(
        token,
        'token',
        'Bangumi token cannot be empty.',
      );
    }
    _token = normalizedToken;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
