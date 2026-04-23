# 阶段3：跨端同步内核（WebDAV / S3-compatible）

## 目标

建立 Android 与 Windows 之间稳定的增量同步能力。

阶段3只解决“同一个应用数据在多设备之间一致”的问题。
它不替代 Bangumi 外部平台同步，也不依赖 Bangumi 账号。

## 前置依赖

* 强依赖 `04-19-phase1-local-core`
* 与 `04-19-phase2-bangumi-flow` 可部分并行
* 最终联调依赖阶段2完成，因为 Bangumi 条目也会携带 `sourceIdsJson`

## 范围

* 对象 / 日志同步模型
* 本地同步队列
* 增量上传与增量拉取
* 冲突判断
* `WebDAV` 适配器
* `S3-compatible` 适配器
* 同步状态最小记录

## 不包含

* 备份导入导出界面
* 同步设置向导细节
* 冲突副本人工处理界面
* Bangumi → 本地导入
* Bangumi 远端进度推送
* 完整同步运维 UI（留到阶段4）

## 父任务冻结边界

本阶段的长期契约归档到：

* `.trellis/spec/architecture/local-first-sync-contract.md`
* `.trellis/spec/architecture/system-boundaries.md`
* `.trellis/spec/backend/database-guidelines.md`

冻结规则：

* 本地数据库是运行时唯一真相源
* `WebDAV` / `S3-compatible` 只是存储和传输适配器
* 同步目标不负责冲突解决
* 日常跨设备同步走对象 / 日志增量
* 快照包只用于备份恢复，不用于日常自动同步
* 冲突判断和合并策略由应用自己维护
* 文本字段冲突必须保留冲突副本，不能静默覆盖

## Requirements

### R1 同步对象契约

同步对象必须具备：

* `updatedAt`
* `deletedAt`
* `syncVersion`
* `deviceId`
* `lastSyncedAt`

这些字段由 repository / sync 层维护。
页面层不得直接写入或推断这些字段。

### R2 增量同步模型

同步按对象或变更增量执行。

要求：

* 不同步整个数据库文件
* 上传只包含本机未同步或已变更对象
* 拉取只处理远端新增或更新对象
* soft delete 作为同步事件传播
* 同步失败可重试，不破坏本地状态

### R3 适配器边界

`WebDAV` 和 `S3-compatible` 适配器只负责：

* 认证 / 连接
* 对象列举
* 对象读取
* 对象写入
* 对象删除或 tombstone 写入

适配器不负责：

* 领域字段解释
* 冲突合并
* 状态映射
* activity log 语义

### R4 冲突策略

首版冲突处理采用：

* 默认最后修改优先
* 重要文本字段保留冲突副本

优先保留冲突副本的字段：

* 短评
* 私人笔记

可直接按最后修改覆盖的字段：

* 状态
* 评分
* 进度
* 列表 / 标签关联

### R5 状态可见但不打扰主流程

阶段3只要求最小状态可见：

* 最近同步时间
* 当前是否正在同步
* 最近一次失败原因摘要
* 是否存在待处理冲突

完整待同步列表、冲突查看和人工重试入口留到阶段4。

## 关键交付

* 两台设备可以通过相同同步目标完成稳定增量同步

## 验收标准

* [ ] 同步按对象或变更增量执行，不同步整库文件
* [ ] 同步对象具备 `updatedAt`、`deletedAt`、`syncVersion`、`deviceId`、`lastSyncedAt`
* [ ] `WebDAV` 和 `S3-compatible` 至少各有一个可用实现
* [ ] 状态、评分、进度、列表、标签可跨设备同步
* [ ] 文本字段冲突时保留冲突副本
* [ ] 同步失败不回滚本地数据
* [ ] 同步目标不可用时，应用仍可本地使用
* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过

## 候选子任务拆分（阶段3启动时再创建）

为保持任务树稳定，父任务先冻结共享契约。
阶段3现已完成子任务拆分，后续按下面顺序推进：

1. `04-22-phase3-wp1-sync-model-queue`
2. `04-22-phase3-wp2-sync-engine-core`
3. `04-22-phase3-wp3-webdav-adapter`
4. `04-22-phase3-wp4-s3-adapter`
5. `04-22-phase3-wp5-conflict-status`

## 额外说明

* 同步目标只是存储介质，不是冲突解决器
* 同步逻辑必须由应用自己维护
* 若阶段3实现时发现需要改同步字段或冲突策略，必须同步更新本 PRD 和 `.trellis/spec/architecture/local-first-sync-contract.md`

## Relevant Specs

* `.trellis/spec/architecture/local-first-sync-contract.md`
  * 定义 local-first、适配器边界、冲突策略与最小同步字段
* `.trellis/spec/architecture/system-boundaries.md`
  * 约束 feature / repository / DAO / provider 的分层与依赖方向
* `.trellis/spec/architecture/task-spec-governance.md`
  * 约束父任务、子任务与 `spec/` 的职责落点
* `.trellis/spec/backend/database-guidelines.md`
  * 约束 Drift 表、软删除、同步字段与 repository 所有权
* `.trellis/spec/backend/error-handling.md`
  * 约束 sync 相关 typed error、summary 反馈与 local-first 错误策略
* `.trellis/spec/backend/directory-structure.md`
  * 约束非 UI 代码的目录归属
* `.trellis/spec/backend/quality-guidelines.md`
  * 约束 controller / repository / service 的职责与测试面
* `.trellis/spec/guides/cross-layer-thinking-guide.md`
  * 提醒先画清楚数据流与边界格式
* `.trellis/spec/guides/code-reuse-thinking-guide.md`
  * 提醒不要把同步 stamping、冲突判断、adapter contract 写散

## Code Patterns Found

* `lib/features/bangumi/data/bangumi_pull_service.dart`
  * 已有“批量拉取 -> 本地优先合并 -> summary 回写”的现成样板
* `lib/features/bangumi/data/bangumi_sync_service.dart`
  * 已有“本地先写 -> 远端 side effect -> 成功后 markSynced”的现成样板
* `lib/features/bangumi/data/bangumi_sync_status.dart`
  * 已有“最小同步状态 + summary + typed error 映射”的状态模型
* `lib/shared/data/repositories/media_repository.dart`
  * 已有 remote apply 与 `markSynced(...)` 落点，但只覆盖 media item
* `lib/shared/data/repositories/user_entry_repository.dart`
  * 已有 remote apply 与 `markSynced(...)` 落点，但只覆盖 status / score
* `lib/shared/data/providers.dart`
  * 只适合 cross-feature repository provider，不适合直接塞 feature sync provider
* `lib/features/settings/presentation/settings_page.dart`
  * `Cloud Sync` 还是只读占位，适合阶段3接最小状态，不适合塞完整运维 UI

## Research Notes

### 已有基础

* 业务表已经普遍带上 `updatedAt` / `deletedAt` / `syncVersion` / `deviceId` / `lastSyncedAt`
* `Bangumi` 的 push / pull 已经验证了 local-first 写路径与 summary 反馈模型
* repository 层已经是写入主入口，符合阶段3继续扩展的落点
* 设置页已经有 `Cloud Sync` 区块，阶段3可以只接最小可见状态

### 当前缺口

* `DeviceIdentityService` 只会生成 UUID，不会持久化当前设备身份
* 多个 repository 的 `_getDeviceId()` 仍返回空字符串，跨设备语义还没落地
* `syncVersion` 目前只有字段，没有统一递增规则，不能直接当唯一增量依据
* `ProgressRepository` / `TagRepository` / `ShelfRepository` 还没有 remote apply 与 `markSynced(...)` 能力
* 代码里还没有同步队列、远端 adapter contract、冲突副本、设备同步状态中心
* `Cloud Sync` 还没有 provider 驱动的数据面，只是文案占位

### 推导结论

* 阶段3必须先补“设备身份 + 队列/状态模型 + adapter contract”，再做具体传输层
* 首版增量判定不能只靠 `syncVersion`，应先用 `updatedAt` / `deletedAt` / `lastSyncedAt` 跑通闭环
* `WebDAV` 与 `S3-compatible` 要复用一套 storage-only adapter contract
* 同步 feature 应新建 `lib/features/sync/data/`，不要把 feature provider 塞进 `lib/shared/data/providers.dart`

## Technical Approach

### 模块落点

新增 `lib/features/sync/data/`，承接：

* 同步实体快照模型
* 本地同步队列与状态模型
* 同步编排器 / pull-push 引擎
* `WebDAV` / `S3-compatible` adapter contract 与实现
* 最小同步状态 provider

保留现有分层：

* `lib/shared/data/`
  * 继续负责表、DAO、repository、sync 字段 stamping
* `lib/features/sync/data/`
  * 负责同步 feature 的 controller / service / adapter / provider
* `lib/features/settings/presentation/`
  * 只消费最小状态，不直接操作 DAO 或 transport client

### 增量策略

首版按“本地字段变化 + 远端对象变化”增量同步：

* 本地上传判定优先看：
  * `deletedAt`
  * `lastSyncedAt == null`
  * `updatedAt > lastSyncedAt`
* 远端拉取判定由同步引擎维护批次水位或对象更新时间
* `syncVersion` 保留为长期字段，但首版不把它当唯一真相

### 适配器边界

统一抽象 storage adapter，只负责：

* 连接 / 认证
* 列举对象
* 读取对象
* 写入对象
* 删除对象或写 tombstone

不负责：

* 业务字段解释
* 冲突判断
* 合并策略
* UI 状态

### 冲突策略

* 标量字段：
  * `status` / `score` / `progress` / 列表 / 标签按最后修改优先
* 文本字段：
  * `notes` / `review` 冲突时保留副本，不能静默覆盖
* 阶段3只记录“有冲突”和冲突副本，不做完整人工处理界面

### 最小 UI 策略

阶段3只把下面这些状态接到设置页：

* 最近同步时间
* 当前是否正在同步
* 最近一次失败摘要
* 是否存在待处理冲突

连接表单、待同步明细、手动重试、冲突查看留给阶段4。

## Decision (ADR-lite)

**Context**

阶段3要在现有 Bangumi local-first 样板上扩成跨设备同步，但当前仓储层只完成了同步字段铺底，还没有设备身份、同步队列和通用 adapter contract。

**Decision**

1. 新建 `lib/features/sync/data/`，集中放同步 feature 的 service / provider / adapter
2. 首版增量判定先用 `updatedAt` / `deletedAt` / `lastSyncedAt` 跑通，不等待完整 `syncVersion` 体系重构
3. `WebDAV` 与 `S3-compatible` 共用一套 storage-only adapter contract
4. 阶段3只交付最小同步状态展示，不提前做阶段4运维 UI
5. 文本冲突只保留副本与摘要状态，不做复杂 diff / merge UI

**Consequences**

* 阶段3可以先打通端到端同步，不被 `syncVersion` 改造卡住
* 需要补一轮 repository 与 queue 的基础设施
* WebDAV / S3 可以并行开发，但必须依赖统一 adapter contract
* 设置页阶段3只会从“占位文案”升级到“最小状态面板”

## Implementation Plan (small PRs)

* **PR1 / WP1：同步对象模型与本地队列**
  * 持久化设备身份
  * 定义 sync feature 模型、队列表、状态表、provider
  * 补齐 repository 的设备 ID / remote apply / markSynced 基础能力
* **PR2 / WP2：增量上传与拉取引擎**
  * 实现 push / pull 编排、批次 summary、错误映射、回写 `lastSyncedAt`
  * 用 fake adapter 打通端到端测试
* **PR3 / WP3：WebDAV 适配器**
  * 落 WebDAV list/read/write/delete/tombstone
* **PR4 / WP4：S3-compatible 适配器**
  * 落 S3-compatible list/read/write/delete/tombstone
* **PR5 / WP5：冲突副本与最小状态展示**
  * 文本冲突副本
  * 设置页最小状态面板
  * regression tests

## Technical Notes

### 重点代码路径

入口  `lib/features/bangumi/data/bangumi_pull_service.dart`
      现成的批量 pull / merge / summary 样板

入口  `lib/features/bangumi/data/bangumi_sync_service.dart`
      现成的 local-first push 与 `markSynced(...)` 样板

实现  `lib/shared/data/repositories/media_repository.dart`
      已有媒体条目 remote apply 与同步字段回写入口

实现  `lib/shared/data/repositories/user_entry_repository.dart`
      已有状态/评分 remote apply 与同步字段回写入口

实现  `lib/shared/data/repositories/progress_repository.dart`
      目前只有本地写，没有 remote apply / markSynced

实现  `lib/shared/data/repositories/tag_repository.dart`
      目前只有本地 attach/detach/syncNames，没有同步状态语义

实现  `lib/shared/data/repositories/shelf_repository.dart`
      目前只有本地 attach/detach/syncNames，没有同步状态语义

展示  `lib/features/settings/presentation/settings_page.dart`
      `Cloud Sync` 仍是占位，可接阶段3最小状态

### 重点风险

* 设备 ID 仍为空字符串，会直接破坏跨设备写入来源判定
* `syncVersion` 还没递增，不能把它当唯一增量依据
* tag / shelf / progress 的同步写回点还没铺完，阶段3不要只同步 media / entry
