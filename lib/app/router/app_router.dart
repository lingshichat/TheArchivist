import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/add/presentation/add_entry_page.dart';
import '../../features/detail/presentation/detail_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/lists/presentation/lists_center_page.dart';
import '../../features/lists/presentation/list_detail_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../shell/app_shell_scaffold.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const library = '/library';
  static const detail = '/detail';
  static const add = '/add';
  static const lists = '/lists';
  static const listDetail = '/lists/detail';
  static const settings = '/settings';

  static String detailFor(String id) => '$detail/$id';
  static String listDetailFor(String id) => '$listDetail/$id';
}

enum _PageTransitionType { subtleFade, slideIn }

CustomTransitionPage<void> _page({
  required Widget child,
  required GoRouterState state,
  _PageTransitionType type = _PageTransitionType.subtleFade,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: switch (type) {
      _PageTransitionType.subtleFade => const Duration(milliseconds: 200),
      _PageTransitionType.slideIn => const Duration(milliseconds: 280),
    },
    reverseTransitionDuration: switch (type) {
      _PageTransitionType.subtleFade => const Duration(milliseconds: 200),
      _PageTransitionType.slideIn => const Duration(milliseconds: 220),
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (type) {
        case _PageTransitionType.subtleFade:
          final fadeIn = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          );
          final fadeOut = Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
          );
          return FadeTransition(
            opacity: fadeIn,
            child: FadeTransition(
              opacity: fadeOut,
              child: child,
            ),
          );
        case _PageTransitionType.slideIn:
          final slide = Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            ),
          );
          final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOut,
            ),
          );
          return FadeTransition(
            opacity: fadeIn,
            child: FadeTransition(
              opacity: fadeOut,
              child: SlideTransition(position: slide, child: child),
            ),
          );
      }
    },
  );
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
              return _page(child: const HomePage(), state: state);
            },
          ),
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) {
              return _page(child: const LibraryPage(), state: state);
            },
          ),
          GoRoute(
            path: '${AppRoutes.detail}/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return _page(
                child: DetailPage(mediaId: id),
                state: state,
                type: _PageTransitionType.slideIn,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.lists,
            pageBuilder: (context, state) {
              return _page(child: const ListsCenterPage(), state: state);
            },
          ),
          GoRoute(
            path: '${AppRoutes.listDetail}/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return _page(
                child: ListDetailPage(listId: id),
                state: state,
                type: _PageTransitionType.slideIn,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.add,
            pageBuilder: (context, state) {
              return _page(
                child: const AddEntryPage(),
                state: state,
                type: _PageTransitionType.slideIn,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) {
              return _page(child: const SettingsPage(), state: state);
            },
          ),
        ],
      ),
    ],
  );
});
