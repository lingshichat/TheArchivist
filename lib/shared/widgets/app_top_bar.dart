import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.actionIcon,
    required this.searchFieldWidth,
    this.isBrandBar = false,
    this.horizontalPadding = AppSpacing.xl,
    this.verticalPadding = AppSpacing.md,
  });

  final String title;
  final String searchHint;
  final IconData actionIcon;
  final double searchFieldWidth;
  final bool isBrandBar;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isBrandBar
                          ? AppColors.accentStrong
                          : AppColors.onSurface,
                      fontWeight: isBrandBar
                          ? FontWeight.w800
                          : FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: searchFieldWidth),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppRadii.container,
                          ),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: AppColors.subtleText,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                searchHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            onPressed: () {},
            splashRadius: 18,
            icon: Icon(actionIcon, color: AppColors.subtleText),
            tooltip: title,
          ),
        ],
      ),
    );
  }
}
