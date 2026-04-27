import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/bangumi/data/bangumi_auth.dart';
import '../../../features/bangumi/data/bangumi_oauth_service.dart';
import '../../../features/bangumi/data/providers.dart';
import '../../../features/bangumi/data/bangumi_sync_status.dart';
import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../../../shared/widgets/section_card.dart';

class BangumiConnectionSection extends ConsumerStatefulWidget {
  const BangumiConnectionSection({super.key});

  @override
  ConsumerState<BangumiConnectionSection> createState() =>
      _BangumiConnectionSectionState();
}

enum _BangumiConnectionAction { none, manualConnect, oauthConnect, disconnect }

class _BangumiConnectionSectionState
    extends ConsumerState<BangumiConnectionSection> {
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  _BangumiConnectionAction _pendingAction = _BangumiConnectionAction.none;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /*
     * ========================================================================
     * 步骤1：根据 Bangumi 认证状态渲染设置区块
     * ========================================================================
     * 目标：
     *   1) 在未连接、恢复中、已连接三种状态间切换统一 UI
     *   2) 保持设置页右侧分组面板的 Stitch 风格不漂移
     */

    // 1.1 读取当前认证异步状态，并派生区块显示模式
    final theme = Theme.of(context);
    final authAsync = ref.watch(bangumiAuthProvider);
    final oauthConfig = ref.watch(bangumiOAuthConfigProvider);
    final oauthService = ref.watch(bangumiOAuthServiceProvider);
    final syncStatus = ref.watch(bangumiSyncStatusProvider);
    final auth = authAsync.valueOrNull;
    final isBusy =
        authAsync.isLoading ||
        syncStatus.isRunning ||
        _pendingAction != _BangumiConnectionAction.none;

    // 1.2 用统一 SectionCard 承载连接信息与操作控件
    return SectionCard(
      title: 'Bangumi Connection',
      leading: const Icon(
        Icons.travel_explore_rounded,
        size: 18,
        color: AppColors.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect your Bangumi account to import existing collections and keep status/rating changes in sync after local saves.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Get an access token from next.bgm.tv/demo/access-token.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            oauthConfig == null
                ? 'Browser login is available when BANGUMI_CLIENT_ID, BANGUMI_CLIENT_SECRET, and BANGUMI_REDIRECT_URI are passed by --dart-define.'
                : 'Browser login is enabled for this desktop build.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (auth != null)
            _buildConnectedState(
              context,
              auth: auth,
              isBusy: isBusy,
              syncStatus: syncStatus,
            )
          else
            _buildDisconnectedState(
              context,
              authAsync: authAsync,
              isBusy: isBusy,
              oauthLoginEnabled: oauthService != null,
            ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState(
    BuildContext context, {
    required AsyncValue<BangumiAuth?> authAsync,
    required bool isBusy,
    required bool oauthLoginEnabled,
  }) {
    /*
     * ========================================================================
     * 步骤2：渲染未连接状态和 token 输入区
     * ========================================================================
     * 目标：
     *   1) 让用户在设置页直接验证并绑定 Bangumi
     *   2) 在恢复失败或连接失败时展示轻量错误信息
     */

    // 2.1 根据当前动作决定按钮与状态文案
    final theme = Theme.of(context);
    final statusText = switch (_pendingAction) {
      _BangumiConnectionAction.manualConnect => 'Verifying token...',
      _BangumiConnectionAction.oauthConnect => 'Waiting for Bangumi login...',
      _BangumiConnectionAction.disconnect => 'Disconnecting...',
      _BangumiConnectionAction.none when authAsync.isLoading =>
        'Checking saved Bangumi token...',
      _ => 'Not connected',
    };

    final errorText = authAsync.hasError
        ? _errorMessageFor(authAsync.error!)
        : null;

    // 2.2 组合 token 输入框、状态提示和连接按钮
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy || !oauthLoginEnabled
                ? null
                : _handleBrowserLogin,
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: Text(isBusy ? 'Working...' : 'Sign in with Browser'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'or connect with a manual token',
            style: theme.textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STATUS', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                statusText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  errorText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _tokenController,
          obscureText: _obscureToken,
          enabled: !isBusy,
          style: AppFormStyles.fieldText(theme),
          decoration:
              AppFormStyles.fieldDecoration(
                theme,
                label: 'Access Token',
                hintText: 'Paste your Bangumi access token',
                surface: AppFormSurface.lowest,
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          setState(() => _obscureToken = !_obscureToken);
                        },
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isBusy ? null : _handleConnect,
            child: Text(isBusy ? 'Working...' : 'Verify and Connect'),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedState(
    BuildContext context, {
    required BangumiAuth auth,
    required bool isBusy,
    required BangumiSyncStatusState syncStatus,
  }) {
    /*
     * ========================================================================
     * 步骤3：渲染已连接状态和断开操作
     * ========================================================================
     * 目标：
     *   1) 展示当前已连接的 Bangumi 账号摘要
     *   2) 允许用户在设置页直接断开并清理本地 token
     */

    // 3.1 组合头像、用户名、签名与断开按钮
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BangumiAvatar(url: auth.avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONNECTED', style: theme.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      auth.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('@${auth.username}', style: theme.textTheme.bodySmall),
                    if (auth.signature != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        auth.signature!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSyncSummaryPanel(context, syncStatus: syncStatus),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: _syncPrimaryButtonStyle(theme),
                  onPressed: isBusy ? null : () => _handleSyncNow(auth),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(syncStatus.isRunning ? 'Syncing...' : 'Sync now'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  style: _syncSecondaryButtonStyle(theme),
                  onPressed: isBusy ? null : _handleDisconnect,
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSummaryPanel(
    BuildContext context, {
    required BangumiSyncStatusState syncStatus,
  }) {
    /*
     * ========================================================================
     * 步骤4：渲染最近一次 Bangumi 同步摘要
     * ========================================================================
     * 目标：
     *   1) 在设置页集中展示当前同步进度、最近结果和失败文案
     *   2) 避免把批量 pull 结果拆成多条零散反馈
     */

    // 4.1 组装当前同步状态、摘要计数和失败信息
    final theme = Theme.of(context);
    final summary = syncStatus.isRunning ? null : syncStatus.lastSummary;
    final statusText = _syncStatusText(syncStatus);
    final countsText = summary == null ? null : _summaryText(summary);
    final completedText = syncStatus.isRunning
        ? null
        : _lastCompletedText(syncStatus.lastCompletedAt);
    final errorText = syncStatus.lastErrorMessage;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    final secondaryTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.bodyText,
      height: 1.5,
      fontWeight: FontWeight.w500,
    );
    final summaryTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.onSurface,
      height: 1.6,
      fontWeight: FontWeight.w600,
    );

    // 4.2 用独立信息卡片承载同步摘要
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SYNC STATUS', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          if (completedText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(completedText, style: secondaryTextStyle),
          ],
          if (countsText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(countsText, style: summaryTextStyle),
          ],
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleBrowserLogin() async {
    /*
     * ========================================================================
     * 步骤5：通过系统浏览器完成 Bangumi OAuth 登录
     * ========================================================================
     * 目标：
     *   1) 拉起网页登录授权，而不是要求用户手动复制 token
     *   2) 在 OAuth 完成后复用现有认证 provider 验证并持久化 token
     */

    // 4.1 读取 OAuth 服务；没有配置时直接提示不可用
    final oauthService = ref.read(bangumiOAuthServiceProvider);
    if (oauthService == null) {
      showLocalFeedback(
        context,
        'Browser login is not configured for this build.',
        tone: LocalFeedbackTone.error,
      );
      return;
    }

    setState(() => _pendingAction = _BangumiConnectionAction.oauthConnect);

    try {
      // 4.2 打开浏览器拿 access token，再交给认证 provider 持久化
      final accessToken = await oauthService.authorize();
      await ref.read(bangumiAuthProvider.notifier).connect(accessToken);
      if (mounted) {
        showLocalFeedback(context, 'Bangumi connected.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          _oauthErrorMessageFor(error),
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _BangumiConnectionAction.none);
      }
    }
  }

  Future<void> _handleConnect() async {
    /*
     * ========================================================================
     * 步骤6：提交 token 并建立 Bangumi 连接
     * ========================================================================
     * 目标：
     *   1) 由页面负责收集输入，认证逻辑交给 provider
     *   2) 连接成功后给出轻反馈并清空输入框
     */

    // 5.1 归一化 token；空值时直接返回
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      showLocalFeedback(
        context,
        'Paste a Bangumi access token first.',
        tone: LocalFeedbackTone.error,
      );
      return;
    }

    setState(() => _pendingAction = _BangumiConnectionAction.manualConnect);

    try {
      // 5.2 交给认证 provider 验证并保存 token
      await ref.read(bangumiAuthProvider.notifier).connect(token);
      _tokenController.clear();
      if (mounted) {
        showLocalFeedback(context, 'Bangumi connected.');
      }
    } catch (_) {
      // 5.3 错误文案由 provider 状态驱动，这里不额外重复弹窗
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _BangumiConnectionAction.none);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    /*
     * ========================================================================
     * 步骤7：断开当前 Bangumi 连接
     * ========================================================================
     * 目标：
     *   1) 删除本地 token 并更新设置页展示
     *   2) 对用户给出稳定的断开反馈
     */

    setState(() => _pendingAction = _BangumiConnectionAction.disconnect);

    try {
      // 6.1 交给认证 provider 清理本地会话
      await ref.read(bangumiAuthProvider.notifier).disconnect();
      if (mounted) {
        showLocalFeedback(context, 'Bangumi disconnected.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          _errorMessageFor(error),
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAction = _BangumiConnectionAction.none);
      }
    }
  }

  Future<void> _handleSyncNow(BangumiAuth auth) async {
    /*
     * ========================================================================
     * 步骤8：触发一次手动 Bangumi 收藏同步
     * ========================================================================
     * 目标：
     *   1) 让用户在设置页主动重新拉取远端状态 / 评分
     *   2) 复用统一同步状态控制器，不在页面里直接调 API
     */

    // 7.1 交给同步状态控制器执行 manual pull；401 时统一失效当前会话
    await ref
        .read(bangumiSyncStatusProvider.notifier)
        .runPull(
          username: auth.username,
          trigger: BangumiSyncTrigger.manual,
          onUnauthorized: ref
              .read(bangumiAuthProvider.notifier)
              .invalidateSession,
        );
  }

  String _errorMessageFor(Object error) {
    if (error is BangumiUnauthorizedError) {
      return 'The Bangumi token is invalid or expired.';
    }

    if (error is BangumiBadRequestError) {
      return 'Bangumi rejected the token verification request.';
    }

    if (error is BangumiNetworkError) {
      return 'Could not reach Bangumi. Check your network and try again.';
    }

    if (error is BangumiServerError) {
      return 'Bangumi is temporarily unavailable.';
    }

    if (error is BangumiApiException) {
      return error.message;
    }

    if (error is ArgumentError) {
      return 'Paste a valid Bangumi token first.';
    }

    return 'Could not verify the Bangumi token.';
  }

  String _oauthErrorMessageFor(Object error) {
    if (error is BangumiOAuthLaunchError) {
      return 'Could not open the browser for Bangumi login.';
    }

    if (error is BangumiOAuthCancelledError) {
      return 'Bangumi login timed out. Try again.';
    }

    if (error is BangumiOAuthCallbackError) {
      return error.message;
    }

    if (error is BangumiOAuthTokenExchangeError) {
      return 'Bangumi login finished, but token exchange failed.';
    }

    if (error is BangumiOAuthUnavailableError) {
      return error.message;
    }

    return _errorMessageFor(error);
  }

  String _syncStatusText(BangumiSyncStatusState syncStatus) {
    if (syncStatus.isRunning) {
      switch (syncStatus.activeTrigger) {
        case BangumiSyncTrigger.manual:
          return 'Syncing Bangumi collections now...';
        case BangumiSyncTrigger.postConnect:
          return 'Importing your Bangumi collections after connect...';
        case BangumiSyncTrigger.startupRestore:
          return 'Refreshing Bangumi collections in the background...';
        case null:
          return 'Syncing Bangumi collections...';
      }
    }

    if (syncStatus.lastCompletedAt != null) {
      return 'Bangumi collections are up to date.';
    }

    return 'No Bangumi sync has run yet.';
  }

  String _summaryText(BangumiPullSummary summary) {
    final segments = <String>[
      'Imported ${summary.importedCount}',
      'Updated ${summary.updatedCount}',
      'Skipped ${summary.skippedCount}',
    ];

    if (summary.localWinsCount > 0) {
      segments.add('Local wins ${summary.localWinsCount}');
    }

    if (summary.failedCount > 0) {
      segments.add('Failed ${summary.failedCount}');
    }

    return segments.join(' · ');
  }

  String? _lastCompletedText(DateTime? completedAt) {
    if (completedAt == null) {
      return null;
    }

    final local = completedAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Last synced $year-$month-$day $hour:$minute';
  }

  ButtonStyle _syncPrimaryButtonStyle(ThemeData theme) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.accentForeground,
      disabledBackgroundColor: AppColors.surfaceContainerHigh,
      disabledForegroundColor: AppColors.bodyText,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }

  ButtonStyle _syncSecondaryButtonStyle(ThemeData theme) {
    return AppFormStyles.secondaryButton(
      theme,
      surface: AppFormSurface.lowest,
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.surfaceContainerLowest;
        }
        return null;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.bodyText;
        }
        return AppColors.onSurface;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.28),
          );
        }
        return BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.36),
        );
      }),
    );
  }
}

class _BangumiAvatar extends StatelessWidget {
  const _BangumiAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        size: 20,
        color: AppColors.subtleText,
      ),
    );

    final normalizedUrl = url?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Image.network(
        normalizedUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
