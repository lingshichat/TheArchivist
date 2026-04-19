import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/detail/presentation/detail_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../shell/app_shell_scaffold.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const library = '/library';
  static const detail = '/detail';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShellScaffold(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: HomePage());
            },
          ),
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: LibraryPage());
            },
          ),
          GoRoute(
            path: AppRoutes.detail,
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: DetailPage());
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: SettingsPage());
            },
          ),
        ],
      ),
    ],
  );
});
