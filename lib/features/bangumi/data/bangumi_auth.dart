import 'bangumi_models.dart';

class BangumiAuth {
  const BangumiAuth({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.signature,
  });

  factory BangumiAuth.fromUser(BangumiUserDto user) {
    /*
     * ========================================================================
     * 步骤1：把 Bangumi 用户 DTO 映射成应用认证视图模型
     * ========================================================================
     * 目标：
     *   1) 统一设置页和认证状态需要的用户摘要字段
     *   2) 避免 UI 直接依赖远端 DTO 结构
     */

    // 1.1 归一化用户可展示名称，优先昵称，其次用户名
    final normalizedUsername = _normalizeOptional(user.username);
    final normalizedNickname = _normalizeOptional(user.nickname);
    final displayName =
        normalizedNickname ?? normalizedUsername ?? 'Bangumi User #${user.id}';

    // 1.2 选择一个稳定的头像 URL 作为设置页展示源
    final avatar =
        _normalizeOptional(user.avatar?.large) ??
        _normalizeOptional(user.avatar?.common) ??
        _normalizeOptional(user.avatar?.medium) ??
        _normalizeOptional(user.avatar?.small) ??
        _normalizeOptional(user.avatar?.grid);

    // 1.3 返回 UI 可直接消费的认证摘要
    return BangumiAuth(
      userId: user.id,
      username: normalizedUsername ?? displayName,
      displayName: displayName,
      avatarUrl: avatar,
      signature: _normalizeOptional(user.sign),
    );
  }

  final int userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? signature;

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
