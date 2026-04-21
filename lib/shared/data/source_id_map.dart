import 'dart:convert';

abstract final class SourceIdMap {
  static Map<String, String> decode(String? rawValue) {
    /*
     * ========================================================================
     * 步骤1：解析来源映射 JSON
     * ========================================================================
     * 目标：
     *   1) 把 `sourceIdsJson` 转成稳定的 `Map<String, String>`
     *   2) 遇到空值、坏 JSON、非对象结构时返回空映射
     */

    // 1.1 归一化空值
    final normalizedValue = rawValue?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return const <String, String>{};
    }

    try {
      // 1.2 解析 JSON 文本
      final decoded = jsonDecode(normalizedValue);
      if (decoded is! Map) {
        return const <String, String>{};
      }

      // 1.3 只保留可序列化的字符串键值
      return decoded.map<String, String>((key, value) {
        return MapEntry(key.toString(), value.toString());
      });
    } on FormatException {
      // 1.4 坏 JSON 降级为空映射
      return const <String, String>{};
    }
  }

  static String encode(Map<String, String> ids) {
    /*
     * ========================================================================
     * 步骤2：生成来源映射 JSON
     * ========================================================================
     * 目标：
     *   1) 统一 `sourceIdsJson` 的序列化出口
     *   2) 保证 provider key 和 sourceId 都被转成字符串
     */

    // 2.1 规范化键值
    final normalizedIds = ids.map<String, String>((key, value) {
      return MapEntry(key.toString(), value.toString());
    });

    // 2.2 输出 JSON 文本
    return jsonEncode(normalizedIds);
  }

  static String? get(String? rawValue, String provider) {
    /*
     * ========================================================================
     * 步骤3：读取指定 provider 的来源 ID
     * ========================================================================
     * 目标：
     *   1) 复用统一解析逻辑
     *   2) 在 controller / provider 里直接读取单个来源值
     */

    // 3.1 解析全部来源映射
    final sourceIds = decode(rawValue);

    // 3.2 返回目标 provider 的值
    return sourceIds[provider];
  }
}
