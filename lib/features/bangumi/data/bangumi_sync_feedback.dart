import 'package:flutter_riverpod/flutter_riverpod.dart';

class BangumiSyncFeedbackEvent {
  const BangumiSyncFeedbackEvent({
    required this.id,
    required this.message,
    required this.isError,
    required this.displayDelay,
  });

  final int id;
  final String message;
  final bool isError;
  final Duration displayDelay;
}

class BangumiSyncFeedbackController
    extends Notifier<BangumiSyncFeedbackEvent?> {
  int _nextId = 0;

  @override
  BangumiSyncFeedbackEvent? build() {
    return null;
  }

  void publishSuccess(
    String message, {
    Duration displayDelay = const Duration(milliseconds: 800),
  }) {
    /*
     * ========================================================================
     * 步骤1：发布同步成功轻反馈事件
     * ========================================================================
     * 目标：
     *   1) 让本地保存提示先展示，再轻量补充远端同步成功状态
     *   2) 保持服务层不依赖 BuildContext
     */

    // 1.1 生成一个新的成功事件，供全局 listener 消费
    state = BangumiSyncFeedbackEvent(
      id: ++_nextId,
      message: message,
      isError: false,
      displayDelay: displayDelay,
    );
  }

  void publishFailure(String message, {Duration displayDelay = Duration.zero}) {
    /*
     * ========================================================================
     * 步骤2：发布同步失败轻反馈事件
     * ========================================================================
     * 目标：
     *   1) 在不打断主流程的前提下提示远端同步失败
     *   2) 让失败提示能立即覆盖当前反馈
     */

    // 2.1 生成一个新的失败事件，供全局 listener 消费
    state = BangumiSyncFeedbackEvent(
      id: ++_nextId,
      message: message,
      isError: true,
      displayDelay: displayDelay,
    );
  }

  void clearIfCurrent(int id) {
    /*
     * ========================================================================
     * 步骤3：按事件 ID 清理已消费反馈
     * ========================================================================
     * 目标：
     *   1) 避免旧事件在 provider 中残留
     *   2) 保证延迟反馈和连续反馈不会互相误清理
     */

    // 3.1 只在当前事件仍然匹配时才清空 provider 状态
    if (state?.id == id) {
      state = null;
    }
  }
}
