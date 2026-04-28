import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.actionIcon,
    required this.searchFieldWidth,
    this.variant = AppTopBarVariant.home,
    this.horizontalPadding = AppSpacing.xl,
    this.verticalPadding = AppSpacing.md,
  });

  final String title;
  final String searchHint;
  final IconData actionIcon;
  final double searchFieldWidth;
  final AppTopBarVariant variant;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _TopBarStyle style = _styleFor(theme);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double contentWidth = math.max(
              0,
              constraints.maxWidth - (horizontalPadding * 2),
            );
            final double maxSearchWidth = math.min(
              searchFieldWidth,
              math.max(
                180,
                contentWidth - style.titleSlotWidth - style.searchGap - 80,
              ),
            );

            return Container(
              height: 64,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(color: style.backgroundColor),
              child: Row(
                children: [
                  SizedBox(
                    width: style.titleSlotWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.titleStyle,
                      ),
                    ),
                  ),
                  SizedBox(width: style.searchGap),
                  SizedBox(
                    width: maxSearchWidth,
                    child: _SearchShell(hint: searchHint, style: style),
                  ),
                  const Spacer(),
                  _TopBarActionButton(
                    icon: actionIcon,
                    pill: style.actionUsesPill,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _TopBarStyle _styleFor(ThemeData theme) {
    switch (variant) {
      case AppTopBarVariant.home:
        return _TopBarStyle(
          titleStyle:
              theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Inter', 'Segoe UI', 'Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
          backgroundColor: AppColors.background.withValues(alpha: 0.72),
          blurSigma: 12,
          searchBackground: AppColors.surfaceContainerLow.withValues(
            alpha: 0.7,
          ),
          searchRadius: AppRadii.container,
          actionUsesPill: true,
          titleSlotWidth: 188,
          searchGap: AppSpacing.xl,
        );
      case AppTopBarVariant.library:
        return _TopBarStyle(
          titleStyle:
              theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Inter', 'Segoe UI', 'Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
          backgroundColor: AppColors.background.withValues(alpha: 0.72),
          blurSigma: 12,
          searchBackground: AppColors.surfaceContainerLow.withValues(
            alpha: 0.7,
          ),
          searchRadius: AppRadii.container,
          actionUsesPill: true,
          titleSlotWidth: 188,
          searchGap: AppSpacing.xl,
        );
      case AppTopBarVariant.detail:
        return _TopBarStyle(
          titleStyle:
              theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.accentStrong,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Inter', 'Segoe UI', 'Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.accentStrong,
              ),
          backgroundColor: AppColors.background.withValues(alpha: 0.72),
          blurSigma: 12,
          searchBackground: AppColors.surfaceContainerLow.withValues(
            alpha: 0.7,
          ),
          searchRadius: AppRadii.container,
          actionUsesPill: true,
          titleSlotWidth: 188,
          searchGap: AppSpacing.xl,
        );
      case AppTopBarVariant.lists:
        return _TopBarStyle(
          titleStyle:
              theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Inter', 'Segoe UI', 'Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
          backgroundColor: AppColors.background.withValues(alpha: 0.72),
          blurSigma: 12,
          searchBackground: AppColors.surfaceContainerLow.withValues(
            alpha: 0.7,
          ),
          searchRadius: AppRadii.container,
          actionUsesPill: true,
          titleSlotWidth: 188,
          searchGap: AppSpacing.xl,
        );
      case AppTopBarVariant.settings:
        return _TopBarStyle(
          titleStyle:
              theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Inter', 'Segoe UI', 'Roboto'],
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ) ??
              const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Inter', 'Segoe UI', 'Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
          backgroundColor: AppColors.background.withValues(alpha: 0.72),
          blurSigma: 12,
          searchBackground: AppColors.surfaceContainerLow.withValues(
            alpha: 0.7,
          ),
          searchRadius: AppRadii.container,
          actionUsesPill: true,
          titleSlotWidth: 188,
          searchGap: AppSpacing.xl,
        );
    }
  }
}

enum AppTopBarVariant { home, library, lists, detail, settings }

class _SearchShell extends StatelessWidget {
  const _SearchShell({required this.hint, required this.style});

  final String hint;
  final _TopBarStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: style.searchBackground,
        borderRadius: BorderRadius.circular(style.searchRadius),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
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
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({required this.icon, required this.pill});

  final IconData icon;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, size: 20, color: AppColors.subtleText);

    if (!pill) {
      return InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: iconWidget,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

class _TopBarStyle {
  const _TopBarStyle({
    required this.titleStyle,
    required this.backgroundColor,
    required this.blurSigma,
    required this.searchBackground,
    required this.searchRadius,
    this.actionUsesPill = false,
    this.titleSlotWidth = 188,
    this.searchGap = AppSpacing.xl,
  });

  final TextStyle titleStyle;
  final Color backgroundColor;
  final double blurSigma;
  final Color searchBackground;
  final double searchRadius;
  final bool actionUsesPill;
  final double titleSlotWidth;
  final double searchGap;
}
