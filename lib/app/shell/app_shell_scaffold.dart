import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../router/app_router.dart';

class AppShellScaffold extends StatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static const double _sidebarWidth = 256;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  bool _drawerOpen = false;

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _contentBackgroundForPath(widget.currentPath),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 768;

            return Stack(
              children: [
                Row(
                  children: [
                    if (!isNarrow)
                      SizedBox(
                        width: AppShellScaffold._sidebarWidth,
                        child: _buildSidebar(),
                      ),
                    Expanded(
                      child: _buildContentArea(isNarrow: isNarrow),
                    ),
                  ],
                ),
                if (isNarrow && _drawerOpen)
                  _buildDrawerOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return DecoratedBox(
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
              isActive: _isHomeSelected(widget.currentPath),
              onTap: () => context.go(AppRoutes.home),
            ),
            _SidebarNavItem(
              label: 'Library',
              icon: Icons.grid_view_rounded,
              isActive: _isLibrarySelected(widget.currentPath),
              onTap: () => context.go(AppRoutes.library),
            ),
            _SidebarNavItem(
              label: 'Lists',
              icon: Icons.bookmark_border_rounded,
              isActive: _isListsSelected(widget.currentPath),
              onTap: () => context.go(AppRoutes.lists),
            ),
            _SidebarNavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              isActive: _isSettingsSelected(widget.currentPath),
              onTap: () => context.go(AppRoutes.settings),
            ),
            const Spacer(),
            const _SidebarProfile(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea({required bool isNarrow}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _contentBackgroundForPath(widget.currentPath),
      ),
      child: Column(
        children: [
          if (isNarrow)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  top: AppSpacing.md,
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: _openDrawer,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _topBarMaxWidthForPath(widget.currentPath),
              ),
              child: AppTopBar(
                title: _topBarTitleForPath(widget.currentPath),
                searchHint: _searchHintForPath(widget.currentPath),
                actionIcon: _actionIconForPath(widget.currentPath),
                searchFieldWidth: _searchWidthForPath(widget.currentPath),
                variant: _topBarVariantForPath(widget.currentPath),
                horizontalPadding: _horizontalPaddingForPath(
                  widget.currentPath,
                ),
                verticalPadding: _verticalPaddingForPath(widget.currentPath),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _contentMaxWidthForPath(widget.currentPath),
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerOverlay() {
    return GestureDetector(
      onTap: _closeDrawer,
      child: Container(
        color: AppColors.background.withValues(alpha: 0.7),
        child: GestureDetector(
          onTap: () {},
          child: SizedBox(
            width: AppShellScaffold._sidebarWidth,
            child: _buildSidebar(),
          ),
        ),
      ),
    );
  }

  static bool _isHomeSelected(String path) => path == AppRoutes.home;

  static bool _isLibrarySelected(String path) {
    return path.startsWith(AppRoutes.library) ||
        path.startsWith(AppRoutes.detail);
  }

  static bool _isListsSelected(String path) {
    return path.startsWith(AppRoutes.lists);
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

    if (path.startsWith(AppRoutes.lists)) {
      return AppTopBarVariant.lists;
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

    if (path.startsWith(AppRoutes.lists)) {
      return 'Lists';
    }

    if (path.startsWith(AppRoutes.detail)) {
      return 'The Archivist';
    }

    if (path.startsWith(AppRoutes.add)) {
      return 'Add Entry';
    }

    return 'Home';
  }

  static String _searchHintForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return 'Search parameters...';
    }

    if (path.startsWith(AppRoutes.library) ||
        path.startsWith(AppRoutes.detail) ||
        path.startsWith(AppRoutes.lists)) {
      return 'Search collection...';
    }

    if (path.startsWith(AppRoutes.add)) {
      return 'Search your archive...';
    }

    return 'Search your archive...';
  }

  static IconData _actionIconForPath(String path) {
    if (path.startsWith(AppRoutes.settings)) {
      return Icons.help_outline_rounded;
    }

    if (path.startsWith(AppRoutes.lists)) {
      return Icons.add_rounded;
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

class _SidebarNavItem extends StatefulWidget {
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
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  void _onEnter(PointerEvent event) => setState(() => _hovered = true);
  void _onExit(PointerEvent event) => setState(() => _hovered = false);

  Color get _backgroundColor {
    if (widget.isActive) {
      return AppColors.surfaceContainerLowest.withValues(alpha: 0.72);
    }
    if (_hovered) {
      return AppColors.surfaceContainerLowest.withValues(alpha: 0.36);
    }
    return Colors.transparent;
  }

  Color get _borderColor {
    if (widget.isActive) {
      return AppColors.accent;
    }
    if (_hovered) {
      return AppColors.outlineVariant.withValues(alpha: 0.3);
    }
    return Colors.transparent;
  }

  Color get _iconColor {
    if (widget.isActive) {
      return AppColors.accent;
    }
    if (_hovered) {
      return AppColors.onSurfaceVariant;
    }
    return AppColors.subtleText;
  }

  Color get _textColor {
    if (widget.isActive) {
      return AppColors.accentStrong;
    }
    if (_hovered) {
      return AppColors.onSurfaceVariant;
    }
    return AppColors.subtleText;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _backgroundColor,
                border: Border(
                  right: BorderSide(
                    color: _borderColor,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: _iconColor,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    widget.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _textColor,
                      fontWeight:
                          widget.isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
