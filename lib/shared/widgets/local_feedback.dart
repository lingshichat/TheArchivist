import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/step_logger.dart';

enum LocalFeedbackTone { success, error }

void showLocalFeedback(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onActionTap,
  LocalFeedbackTone tone = LocalFeedbackTone.success,
}) {
  /*
   * ========================================================================
   * 步骤1：展示本地轻反馈通知
   * ========================================================================
   * 目标：
   *   1) 统一桌面端底部通知条样式
   *   2) 即使带操作按钮也保持自动消失
   */
  const logger = StepLogger('showLocalFeedback');
  logger.info('开始展示本地轻反馈通知...');

  // 1.1 读取主题和当前消息宿主
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.of(context);

  // 1.2 清掉上一条通知，避免多条堆叠
  messenger.hideCurrentSnackBar();

  // 1.3 显示新的通知条，并显式关闭 action=持久展示 的默认行为
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
      ),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 2),
      persist: false,
      content: Align(
        alignment: Alignment.bottomRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _LocalFeedbackBubble(
            theme: theme,
            message: message,
            tone: tone,
            actionLabel: actionLabel,
            onActionTap: onActionTap,
          ),
        ),
      ),
    ),
  );

  logger.info('本地轻反馈通知展示完成。');
}

class _LocalFeedbackBubble extends StatelessWidget {
  const _LocalFeedbackBubble({
    required this.theme,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onActionTap,
  });

  final ThemeData theme;
  final String message;
  final LocalFeedbackTone tone;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    /*
     * ========================================================================
     * 步骤2：渲染统一反馈气泡内容
     * ========================================================================
     * 目标：
     *   1) 让所有本地反馈都走同一套暗色胶囊样式
     *   2) 成功和失败只切 tone，不分裂多套宿主组件
     */

    // 2.1 根据 tone 选择图标和强调色
    final iconData = switch (tone) {
      LocalFeedbackTone.success => Icons.check_circle,
      LocalFeedbackTone.error => Icons.cancel,
    };
    final iconBackgroundColor = switch (tone) {
      LocalFeedbackTone.success => AppColors.accentContainer,
      LocalFeedbackTone.error => AppColors.error.withValues(alpha: 0.18),
    };
    final iconForegroundColor = switch (tone) {
      LocalFeedbackTone.success => AppColors.accentStrong,
      LocalFeedbackTone.error => const Color(0xFFFFD6D4),
    };
    final normalizedActionLabel = actionLabel?.trim();
    final hasAction =
        normalizedActionLabel != null &&
        normalizedActionLabel.isNotEmpty &&
        onActionTap != null;

    // 2.2 用暗色胶囊容器承载图标、文案和可选动作
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2D3338),
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                iconData,
                size: 16,
                color: iconForegroundColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                message,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.surfaceContainerLowest,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.surfaceContainerLowest,
                    ),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: AppSpacing.lg),
              TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentForeground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(normalizedActionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
