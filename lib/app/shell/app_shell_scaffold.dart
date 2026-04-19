import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../router/app_router.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double _sidebarWidth = 256;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _contentBackgroundForPath(currentPath),
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: _sidebarWidth,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: AppColors.shellPanel),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SidebarBrand(),
                      const SizedBox(height: AppSpacing.xxl),
                      _SidebarNavItem(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        isActive: _isHomeSelected(currentPath),
                        onTap: () => context.go(AppRoutes.home),
                      ),
                      _SidebarNavItem(
                        label: 'Library',
                        icon: Icons.grid_view_rounded,
                        isActive: _isLibrarySelected(currentPath),
                        onTap: () => context.go(AppRoutes.library),
                      ),
                      _SidebarNavItem(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        isActive: _isSettingsSelected(currentPath),
                        onTap: () => context.go(AppRoutes.settings),
                      ),
                      const Spacer(),
                      const _SidebarProfile(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _contentBackgroundForPath(currentPath),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _topBarMaxWidthForPath(currentPath),
                        ),
                        child: AppTopBar(
                          title: _topBarTitleForPath(currentPath),
                          searchHint: _searchHintForPath(currentPath),
                          actionIcon: _actionIconForPath(currentPath),
                          searchFieldWidth: _searchWidthForPath(currentPath),
                          variant: _topBarVariantForPath(currentPath),
                          horizontalPadding: _horizontalPaddingForPath(
                            currentPath,
                          ),
                          verticalPadding: _verticalPaddingForPath(currentPath),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _contentMaxWidthForPath(currentPath),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isHomeSelected(String path) => path == AppRoutes.home;

  static bool _isLibrarySelected(String path) {
    return path.startsWith(AppRoutes.library) ||
        path.startsWith(AppRoutes.detail);
  }

  static bool _isSettingsSelected(String path) {
    return path.startsWith(AppRoutes.settings);
  }

  static AppTopBarVariant _topBarVariantForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return AppTopBarVariant.settings;
    }

    if (path.startsWith(AppRoutes.library)) {
      return AppTopBarVariant.library;
    }

    if (path.startsWith(AppRoutes.detail)) {
      return AppTopBarVariant.detail;
    }

    return AppTopBarVariant.home;
  }

  static String _topBarTitleForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return 'Settings';
    }

    if (path.startsWith(AppRoutes.library)) {
      return 'Library';
    }

    if (path.startsWith(AppRoutes.detail)) {
      return 'The Archivist';
    }

    return 'Home';
  }

  static String _searchHintForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return 'Search parameters...';
    }

    if (path.startsWith(AppRoutes.library) ||
        path.startsWith(AppRoutes.detail)) {
      return 'Search collection...';
    }

    return 'Search your archive...';
  }

  static IconData _actionIconForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return Icons.help_outline_rounded;
    }

    return Icons.filter_list_rounded;
  }

  static double _searchWidthForPath(String path) {
    return 360;
  }

  static double _topBarMaxWidthForPath(String path) {
    return 1600;
  }

  static double _contentMaxWidthForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return 1280;
    }

    if (path.startsWith(AppRoutes.detail)) {
      return 1440;
    }

    return 1600;
  }

  static Color _contentBackgroundForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return AppColors.shellPanel;
    }

    return AppColors.background;
  }

  static double _horizontalPaddingForPath(String path) {
    return AppSpacing.xxxl;
  }

  static double _verticalPaddingForPath(String path) {
    return AppSpacing.lg;
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Archivist',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.accentStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('COLLECTIONS', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text('Curated Media', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.surfaceContainerLowest.withValues(alpha: 0.72)
                  : Colors.transparent,
              border: Border(
                right: BorderSide(
                  color: isActive ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? AppColors.accent : AppColors.subtleText,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isActive
                        ? AppColors.accentStrong
                        : AppColors.subtleText,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarProfile extends StatelessWidget {
  const _SidebarProfile();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            'ET',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accentStrong,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elias Thorne',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text('Archivist Lvl 4', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
