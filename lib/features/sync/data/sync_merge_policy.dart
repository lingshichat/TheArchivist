class SyncLocalState {
  const SyncLocalState({
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
    this.lastSyncedAt,
  });

  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final String deviceId;
}

enum SyncMergeDecision { applyRemote, skip, localWins }

class SyncMergePolicy {
  const SyncMergePolicy();

  SyncMergeDecision decide({
    required SyncLocalState? localState,
    required DateTime remoteUpdatedAt,
    required String remoteDeviceId,
  }) {
    if (localState == null) {
      return SyncMergeDecision.applyRemote;
    }

    if (remoteUpdatedAt.isAfter(localState.updatedAt)) {
      return SyncMergeDecision.applyRemote;
    }

    if (localState.updatedAt.isAfter(remoteUpdatedAt)) {
      return SyncMergeDecision.localWins;
    }

    if (localState.deviceId == remoteDeviceId) {
      return SyncMergeDecision.skip;
    }

    return SyncMergeDecision.skip;
  }
}
