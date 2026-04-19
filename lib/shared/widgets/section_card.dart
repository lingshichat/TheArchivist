import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.highlighted = false,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.05)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.floating),
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.16),
          ),
          right: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.16),
          ),
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.16),
          ),
          left: BorderSide(
            color: highlighted
                ? AppColors.accent
                : AppColors.outlineVariant.withValues(alpha: 0.16),
            width: highlighted ? 4 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}
