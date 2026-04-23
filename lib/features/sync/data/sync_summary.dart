class SyncSummary {
  const SyncSummary({
    this.queuedCount = 0,
    this.pushedCount = 0,
    this.deletedCount = 0,
    this.pullAppliedCount = 0,
    this.pullSkippedCount = 0,
    this.localWinsCount = 0,
    this.failedCount = 0,
    this.lastErrorSummary,
  });

  final int queuedCount;
  final int pushedCount;
  final int deletedCount;
  final int pullAppliedCount;
  final int pullSkippedCount;
  final int localWinsCount;
  final int failedCount;
  final String? lastErrorSummary;

  bool get hasFailures => failedCount > 0;
}

class SyncSummaryBuilder {
  int queuedCount = 0;
  int pushedCount = 0;
  int deletedCount = 0;
  int pullAppliedCount = 0;
  int pullSkippedCount = 0;
  int localWinsCount = 0;
  int failedCount = 0;
  String? lastErrorSummary;

  void recordPushSuccess({required bool deleted}) {
    pushedCount += 1;
    if (deleted) {
      deletedCount += 1;
    }
  }

  void recordPullApplied() {
    pullAppliedCount += 1;
  }

  void recordPullSkipped() {
    pullSkippedCount += 1;
  }

  void recordLocalWins() {
    localWinsCount += 1;
  }

  void recordFailure(String message) {
    failedCount += 1;
    lastErrorSummary = message;
  }

  SyncSummary build() {
    return SyncSummary(
      queuedCount: queuedCount,
      pushedCount: pushedCount,
      deletedCount: deletedCount,
      pullAppliedCount: pullAppliedCount,
      pullSkippedCount: pullSkippedCount,
      localWinsCount: localWinsCount,
      failedCount: failedCount,
      lastErrorSummary: lastErrorSummary,
    );
  }
}
