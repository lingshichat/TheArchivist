# 后续增强：Bangumi 进度同步

## 目标

补齐父任务 MVP 中"Bangumi 双向同步首批覆盖收藏状态、进度、评分"的进度同步缺口。

当前阶段2已经完成：

* Bangumi 搜索与快捷添加
* Bangumi 绑定
* 收藏状态同步
* 评分同步
* 首次导入、启动恢复回拉与手动 `Sync now`

本任务只承接"观看 / 阅读 / 游玩进度"同步，不重新打开阶段2已完成范围。

## 来源

来自 `04-18-flutter-media-tracker` 的任务树校准。

阶段2执行时，为控制范围，明确把剧集 / 页数 / 时长进度推送留到后续 follow-up。

## 范围

* 本地 `ProgressEntry` 到 Bangumi 的进度推送
* Bangumi 远端进度到本地的拉取与合并
* 媒介差异映射：
  * 影视：集数 / 剧集进度
  * 书籍：页数进度
  * 游戏：无 Bangumi 进度字段支持，只同步 collection 状态
  * 电影：无 Bangumi 进度字段支持，只同步 collection 状态
* 本地优先合并策略
* 同步失败轻提示与摘要记录
* 对现有 Bangumi 同步状态模型的最小扩展

## 不包含

* 私人笔记同步到 Bangumi
* 自定义标签同步到 Bangumi
* 自定义列表同步到 Bangumi
* 远端删除联动
* 复杂冲突处理中心
* WebDAV / S3-compatible 跨端同步配置

## 详细设计

### 1. Bangumi API 层扩展

**文件**: `lib/features/bangumi/data/bangumi_models.dart`

在 `BangumiCollectionDto` 中新增字段：
- `epStatus: int?` — 对应 Bangumi API 的 `ep_status`，表示已观看集数 / 已阅读页数

**文件**: `lib/features/bangumi/data/bangumi_api_service.dart`

- `getCollection()` 返回的 DTO 已自动包含 `epStatus`
- 在 `updateCollection()` 方法签名中增加可选参数 `int? epStatus`
- `patchCollection()` 已有泛化 PATCH 能力，进度推送复用此方法

### 2. Push 服务

**新建文件**: `lib/features/bangumi/data/bangumi_progress_sync_service.dart`

```dart
abstract class BangumiProgressSyncService {
  Future<void> pushProgress({required String mediaItemId});
}
```

`BangumiProgressSyncService` 实现逻辑：
1. 校验 token、Bangumi subject id 存在（与 collection sync 同前置条件）
2. 读取本地 `ProgressEntry` 和 `MediaItem`
3. 按媒体类型映射进度到 Bangumi `ep_status`：
   - `MediaType.tv`：`progressEntry.currentEpisode` → `ep_status`
   - `MediaType.book`：`progressEntry.currentPage` → `ep_status`
   - `MediaType.movie` / `MediaType.game`：静默跳过（Bangumi 无对应进度字段）
4. 调用 `patchCollection(subjectId, {'ep_status': epStatus})`
5. 成功后 `ProgressRepository.markSynced(mediaItemId, syncedAt)`
6. 错误处理：
   - `BangumiUnauthorizedError` → 清理 token，轻提示
   - 其他 `BangumiApiException` → 轻提示，不回滚本地进度

**文件**: `lib/features/bangumi/data/providers.dart`

新增 provider：
```dart
final bangumiProgressSyncServiceProvider = Provider<BangumiProgressSyncService>(...);
```

### 3. Pull 服务扩展

**文件**: `lib/features/bangumi/data/bangumi_pull_service.dart`

在 `BangumiCollectionPullService._reconcileCollection()` 中加入进度合并：

1. 解析远端进度：`collection.epStatus`
2. 读取本地 `ProgressEntry`
3. 本地脏判断：
   - `progressEntry != null && progressEntry.updatedAt.isAfter(progressEntry.lastSyncedAt ?? DateTime(1970))` → 本地 wins
   - `progressEntry == null || lastSyncedAt == null` → 直接应用远端
4. 应用远端进度：
   - 按媒体类型反向映射 `epStatus` → `currentEpisode` / `currentPage`
   - 调用 `ProgressRepository.applyRemoteProgress()`
5. 更新 `BangumiPullSummary`：已有 `updatedCount` / `skippedCount` / `localWinsCount` 复用

在 `_importMissingCollection()` 中：新建 media item 和 user entry 后，若 `collection.epStatus != null`，同样调用 `applyRemoteProgress` 写入初始进度。

### 4. 触发点

**文件**: `lib/features/detail/data/detail_actions_controller.dart`

- `saveChanges()` 中进度变化时（`_sameProgress` 返回 false），在本地写入完成后追加 Bangumi 进度推送：
  ```dart
  await _bangumiProgressSyncService.pushProgress(mediaItemId: mediaItemId);
  ```
- `applyQuickStatus()` 中状态变为 `done` 时，如果条目是 TV 类型且有 `totalEpisodes`，同时推送进度为总集数

### 5. 本地优先合并策略

规则与现有 collection 合并一致：

| 场景 | 行为 |
|------|------|
| 本地无 ProgressEntry | 直接应用远端进度 |
| 本地有 ProgressEntry，lastSyncedAt 为空 | 直接应用远端进度 |
| 本地 updatedAt > lastSyncedAt | 本地 wins，统计到 `localWinsCount` |
| 本地 updatedAt <= lastSyncedAt | 应用远端进度，统计到 `updatedCount` |
| 远端无进度（epStatus == null）| 不做任何改动 |
| 本地进度 == 远端进度 | `skippedCount` |

### 6. 文件变更清单

| 路径 | 动作 | 说明 |
|------|------|------|
| `lib/features/bangumi/data/bangumi_models.dart` | 修改 | `BangumiCollectionDto` 增加 `epStatus` |
| `lib/features/bangumi/data/bangumi_api_service.dart` | 修改 | `updateCollection` 增加 `epStatus` 参数 |
| `lib/features/bangumi/data/bangumi_progress_sync_service.dart` | 新建 | 进度推送服务 |
| `lib/features/bangumi/data/bangumi_pull_service.dart` | 修改 | `_reconcileCollection` 加入进度合并；`_importMissingCollection` 加入进度导入 |
| `lib/features/bangumi/data/bangumi_sync_status.dart` | 无需修改 | `BangumiPullSummary` 字段已足够 |
| `lib/features/bangumi/data/providers.dart` | 修改 | 新增 `bangumiProgressSyncServiceProvider`；注入 `progressRepositoryProvider` 到 pull service |
| `lib/features/detail/data/detail_actions_controller.dart` | 修改 | `saveChanges` 和 `applyQuickStatus` 中加入进度推送触发 |
| `lib/shared/data/repositories/progress_repository.dart` | 无需修改 | `applyRemoteProgress`、`markSynced` 已就绪 |

## 验收标准

* [ ] 修改本地进度后，已绑定且已映射 Bangumi subject 的 TV/Book 条目可推送进度到 Bangumi
* [ ] 手动 `Sync now` 可拉取 Bangumi 进度并合并到本地
* [ ] 本地存在脏改动时（进度修改后未同步），远端进度不覆盖本地新值
* [ ] 同步失败不回滚本地进度
* [ ] 未绑定 Bangumi 时，本地进度链路不受影响
* [ ] 进度同步不污染 WebDAV / S3-compatible 跨端同步边界
* [ ] Movie / Game 条目修改进度时不触发 Bangumi 进度推送（静默跳过）
* [ ] Pull 导入缺失条目时，Bangumi 中的进度一并导入本地

## 依赖

* 依赖 `04-19-phase2-bangumi-flow`
* 依赖阶段1本地 `ProgressEntry` 链路

## 备注

这是 Bangumi 外部平台同步 follow-up。

它不属于当前 `04-19-phase4-settings-backup` 的设置、备份与同步运维范围。
