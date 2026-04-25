import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.actionLabel,
    required this.onAction,
    required this.onCancel,
    this.actionColor,
  });

  final int selectedCount;
  final int totalCount;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onCancel;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$selectedCount / $totalCount selected',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel'.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            style:
                actionColor != null
                    ? FilledButton.styleFrom(backgroundColor: actionColor)
                    : null,
            onPressed: selectedCount > 0 ? onAction : null,
            child: Text(actionLabel.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
