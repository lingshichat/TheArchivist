import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

void showLocalFeedback(BuildContext context, String message) {
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 0,
      margin: const EdgeInsets.all(AppSpacing.xl),
      duration: const Duration(seconds: 2),
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
    ),
  );
}
