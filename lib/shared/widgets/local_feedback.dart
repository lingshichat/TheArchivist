import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/step_logger.dart';

void showLocalFeedback(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onActionTap,
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
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 0,
      margin: const EdgeInsets.all(AppSpacing.xl),
      duration: const Duration(seconds: 2),
      persist: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
      ),
      action: actionLabel != null && onActionTap != null
          ? SnackBarAction(label: actionLabel, onPressed: onActionTap)
          : null,
    ),
  );

  logger.info('本地轻反馈通知展示完成。');
}
