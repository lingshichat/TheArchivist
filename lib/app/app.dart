import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/bangumi/data/bangumi_sync_feedback.dart';
import '../features/bangumi/data/providers.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/local_feedback.dart';
import 'router/app_router.dart';

class RecordAnywhereApp extends ConsumerWidget {
  const RecordAnywhereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'The Archivist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        return _BangumiSyncFeedbackHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _BangumiSyncFeedbackHost extends ConsumerWidget {
  const _BangumiSyncFeedbackHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<BangumiSyncFeedbackEvent?>(bangumiSyncFeedbackProvider, (
      previous,
      next,
    ) {
      /*
       * ======================================================================
       * 步骤1：监听全局 Bangumi 同步反馈事件
       * ======================================================================
       * 目标：
       *   1) 将 service 层发布的同步结果转成统一轻反馈
       *   2) 让同步成功提示稍晚于“Saved locally.” 展示
       */

      // 1.1 仅处理新的非空事件，避免重复消费
      if (next == null || next.id == previous?.id) {
        return;
      }

      // 1.2 异步消费事件，必要时延迟展示成功提示
      unawaited(_consumeFeedback(context, ref, next));
    });

    return child;
  }

  Future<void> _consumeFeedback(
    BuildContext context,
    WidgetRef ref,
    BangumiSyncFeedbackEvent event,
  ) async {
    /*
     * ========================================================================
     * 步骤2：展示并清理已消费的同步反馈
     * ========================================================================
     * 目标：
     *   1) 用统一 Snackbar 样式展示同步结果
     *   2) 保证延迟事件不会误清理后续新事件
     */

    // 2.1 对成功事件做轻微延迟，避免立刻覆盖本地保存提示
    if (event.displayDelay > Duration.zero) {
      await Future<void>.delayed(event.displayDelay);
    }

    // 2.2 只有在 app 仍可展示反馈时才真正弹出提示
    if (context.mounted) {
      showLocalFeedback(
        context,
        event.message,
        tone: event.isError
            ? LocalFeedbackTone.error
            : LocalFeedbackTone.success,
      );
    }

    // 2.3 按事件 ID 清掉已消费状态，保留更晚到达的新事件
    ref.read(bangumiSyncFeedbackProvider.notifier).clearIfCurrent(event.id);
  }
}
