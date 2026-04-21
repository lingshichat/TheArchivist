import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_sync_feedback.dart';

enum BangumiSyncTrigger { postConnect, startupRestore, manual }

class BangumiPullSummary {
  const BangumiPullSummary({
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.localWinsCount,
    required this.failedCount,
  });

  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int localWinsCount;
  final int failedCount;

  int get totalCount =>
      importedCount +
      updatedCount +
      skippedCount +
      localWinsCount +
      failedCount;
}

abstract class BangumiPullService {
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
  });
}

class BangumiSyncStatusState {
  const BangumiSyncStatusState({
    this.isRunning = false,
    this.activeTrigger,
    this.lastCompletedAt,
    this.lastSummary,
    this.lastErrorMessage,
  });

  final bool isRunning;
  final BangumiSyncTrigger? activeTrigger;
  final DateTime? lastCompletedAt;
  final BangumiPullSummary? lastSummary;
  final String? lastErrorMessage;

  BangumiSyncStatusState copyWith({
    bool? isRunning,
    Object? activeTrigger = _noOverride,
    Object? lastCompletedAt = _noOverride,
    Object? lastSummary = _noOverride,
    Object? lastErrorMessage = _noOverride,
  }) {
    return BangumiSyncStatusState(
      isRunning: isRunning ?? this.isRunning,
      activeTrigger: identical(activeTrigger, _noOverride)
          ? this.activeTrigger
          : activeTrigger as BangumiSyncTrigger?,
      lastCompletedAt: identical(lastCompletedAt, _noOverride)
          ? this.lastCompletedAt
          : lastCompletedAt as DateTime?,
      lastSummary: identical(lastSummary, _noOverride)
          ? this.lastSummary
          : lastSummary as BangumiPullSummary?,
      lastErrorMessage: identical(lastErrorMessage, _noOverride)
          ? this.lastErrorMessage
          : lastErrorMessage as String?,
    );
  }
}

class BangumiSyncStatusController
    extends StateNotifier<BangumiSyncStatusState> {
  BangumiSyncStatusController({
    required BangumiPullService pullService,
    required BangumiSyncFeedbackController feedbackController,
    StepLogger? logger,
  }) : _pullService = pullService,
       _feedbackController = feedbackController,
       _logger = logger ?? const StepLogger('BangumiSyncStatusController'),
       super(const BangumiSyncStatusState());

  final BangumiPullService _pullService;
  final BangumiSyncFeedbackController _feedbackController;
  final StepLogger _logger;

  Future<BangumiPullSummary?> runPull({
    required String username,
    required BangumiSyncTrigger trigger,
    required Future<void> Function() onUnauthorized,
  }) async {
    /*
     * ========================================================================
     * 步骤1：编排一次 Bangumi 批量 pull
     * ========================================================================
     * 目标：
     *   1) 统一管理 running 状态、摘要结果、失败文案
     *   2) 让 auth 恢复和设置页手动同步共用同一编排入口
     */
    _logger.info('开始编排 Bangumi 批量 pull...');

    // 1.1 并发保护；已有同步在跑时直接复用当前状态
    if (state.isRunning) {
      _logger.info('Bangumi 批量 pull 编排完成。');
      return null;
    }

    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      state = state.copyWith(
        lastErrorMessage: 'Bangumi username is missing for sync.',
      );
      _logger.info('Bangumi 批量 pull 编排失败。');
      return null;
    }

    state = state.copyWith(
      isRunning: true,
      activeTrigger: trigger,
      lastErrorMessage: null,
    );

    try {
      // 1.2 执行 pull，并把摘要写回状态供设置页展示
      final summary = await _pullService.pullCollections(
        username: normalizedUsername,
        trigger: trigger,
      );

      state = state.copyWith(
        isRunning: false,
        activeTrigger: null,
        lastCompletedAt: DateTime.now(),
        lastSummary: summary,
        lastErrorMessage: null,
      );

      if (trigger == BangumiSyncTrigger.manual) {
        _feedbackController.publishSuccess(
          _successMessageFor(summary),
          displayDelay: Duration.zero,
        );
      }

      _logger.info('Bangumi 批量 pull 编排完成。');
      return summary;
    } on BangumiUnauthorizedError {
      // 1.3 远端授权失效时统一失效化当前会话
      await onUnauthorized();
      final message = 'Bangumi connection expired. Reconnect in Settings.';
      state = state.copyWith(
        isRunning: false,
        activeTrigger: null,
        lastErrorMessage: message,
      );
      if (trigger == BangumiSyncTrigger.manual) {
        _feedbackController.publishFailure(message);
      }
      _logger.info('Bangumi 批量 pull 编排失败，授权已失效。');
      return null;
    } on BangumiApiException catch (error) {
      // 1.4 一般网络或服务错误只记摘要失败，不影响本地库
      final message = _messageForError(error);
      state = state.copyWith(
        isRunning: false,
        activeTrigger: null,
        lastErrorMessage: message,
      );
      if (trigger == BangumiSyncTrigger.manual) {
        _feedbackController.publishFailure(message);
      }
      _logger.info('Bangumi 批量 pull 编排失败。');
      return null;
    } on ArgumentError {
      final message = 'Could not sync Bangumi collections.';
      state = state.copyWith(
        isRunning: false,
        activeTrigger: null,
        lastErrorMessage: message,
      );
      if (trigger == BangumiSyncTrigger.manual) {
        _feedbackController.publishFailure(message);
      }
      _logger.info('Bangumi 批量 pull 编排失败。');
      return null;
    } catch (_) {
      final message = 'Could not sync Bangumi collections.';
      state = state.copyWith(
        isRunning: false,
        activeTrigger: null,
        lastErrorMessage: message,
      );
      if (trigger == BangumiSyncTrigger.manual) {
        _feedbackController.publishFailure(message);
      }
      _logger.info('Bangumi 批量 pull 编排失败。');
      return null;
    }
  }

  String _successMessageFor(BangumiPullSummary summary) {
    return 'Bangumi sync finished: '
        'imported ${summary.importedCount}, '
        'updated ${summary.updatedCount}, '
        'skipped ${summary.skippedCount}.';
  }

  String _messageForError(BangumiApiException error) {
    switch (error) {
      case BangumiNetworkError():
        return 'Could not reach Bangumi. Check your network and try again.';
      case BangumiBadRequestError():
        return 'Bangumi rejected the collection sync request.';
      case BangumiNotFoundError():
        return 'A Bangumi collection could not be found remotely.';
      case BangumiServerError():
        return 'Bangumi is temporarily unavailable.';
      case BangumiUnknownError():
        return 'Could not sync Bangumi collections.';
      case BangumiUnauthorizedError():
        return 'Bangumi connection expired. Reconnect in Settings.';
    }
  }
}

const Object _noOverride = Object();
