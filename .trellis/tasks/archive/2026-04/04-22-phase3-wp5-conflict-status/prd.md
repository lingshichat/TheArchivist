# 阶段3-WP5：冲突副本与最小状态展示

## Goal

补齐阶段3最后一层可见性：当跨设备同步遇到 `notes` / `review` 文本字段并发修改时，不静默丢失任一侧文本；同时提供一个最小、稳定、provider 驱动的同步状态，让设置页能只读展示同步健康度。

阶段3只解决“看得见、可追溯、可回归测试”的最小闭环，不提前做阶段4的运维面板或人工合并流程。

## What I already know

* 当前任务属于父任务 `04-19-phase3-sync-engine` 的阶段3最后可见性补齐。
* 现有跨设备同步核心已存在：`SyncEngine`、`SyncCodec`、`SyncMergePolicy`、`SyncQueueRepository`、`SyncStatusRepository`。
* 当前最小同步状态已有基础模型：`SyncStatusState` 包含 `isRunning`、`lastCompletedAt`、`lastErrorSummary`、`pendingCount`、`hasConflicts`。
* 当前设置页落点是 `lib/features/settings/presentation/settings_page.dart`，其中 `Cloud Sync` 仍是静态占位文案。
* 当前 merge 基线是 last-modified-wins：远端较新则 `applyRemote`，本地较新则 `localWins`，相同时间按 skip。
* `userEntry` envelope 已携带 `notes`、`review`、`score`、`status` 等字段，因此冲突检测可在 sync feature 层完成，不需要 settings UI 直接读取 repository / DAO。

## Requirements

### R1 文本冲突副本

阶段3首版至少覆盖 `userEntry` 的两个文本字段：

* `notes`
* `review`

冲突判定建议：

* 同一 `mediaItemId` 的本地与远端 `userEntry` 都存在。
* 本地与远端来自不同 `deviceId`。
* 本地与远端都在共同同步基线之后发生过更新。
* `notes` 或 `review` 的本地值与远端值不同。

冲突时：

* 不能静默丢弃本地文本或远端文本。
* 必须记录冲突副本，至少包含：
  * `entityType`
  * `entityId`
  * `fieldName`
  * `localValue`
  * `remoteValue`
  * `localUpdatedAt`
  * `remoteUpdatedAt`
  * `localDeviceId`
  * `remoteDeviceId`
  * `detectedAt`
  * `resolved`
* 阶段3只要求记录副本与“存在冲突”摘要，不要求用户立刻解决。

### R2 标量字段仍保持 last-modified-wins

`status`、`score`、`favorite`、`reconsumeCount`、`startedAt`、`finishedAt` 等非文本副本字段继续遵守现有 last-modified-wins 规则：

* 远端较新：应用远端快照。
* 本地较新：本地获胜，远端不覆盖。
* 相同时间：按现有 `SyncMergePolicy` skip。

文本冲突副本不能把整个 `userEntry` merge 策略改成“冲突即阻塞全部字段”。

### R3 最小同步状态模型

状态 provider 需要能稳定表达：

* 最近同步时间：`lastCompletedAt`
* 当前是否正在同步：`isRunning`
* 最近一次失败原因摘要：`lastErrorSummary`
* 是否存在待处理冲突：`hasConflicts`

状态来源必须在 sync data layer 内统一维护，设置页只读消费 provider。

### R4 设置页最小展示

把 `settings_page.dart` 里的 `Cloud Sync` 从占位文案升级成 provider 驱动的只读状态面板。

阶段3只展示：

* 当前状态
* 最近同步时间
* 最近失败摘要
* 是否有冲突

设置页不得：

* 直接访问 DAO / repository / storage adapter。
* 展示队列明细、重试中心、连接表单或手动合并 UI。
* 把阶段4运维能力提前塞进此面板。

### R5 回归测试

至少覆盖：

* `notes` / `review` 文本冲突副本被保留。
* 标量字段仍按 last-modified-wins 生效。
* 状态 provider 能正确反映 success / running / failure / conflict。
* 设置页可从 provider 状态渲染“有待处理冲突”。

## Acceptance Criteria

* [ ] `notes` 冲突会保留本地与远端副本。
* [ ] `review` 冲突会保留本地与远端副本。
* [ ] 文本冲突存在时，标量字段仍按 last-modified-wins 合并。
* [ ] 最小同步状态可被 `syncStatusProvider` 或等价 provider 消费。
* [ ] 设置页 `Cloud Sync` 不再是静态占位文案。
* [ ] 阶段3只展示最小状态，不提前做阶段4运维面板。
* [ ] 冲突存在时用户能从设置页知道“有待处理冲突”。
* [ ] 新增或更新回归测试覆盖 success / running / failure / conflict。
* [ ] `flutter analyze lib test` 通过。
* [ ] 相关单元测试通过。

## Definition of Done

* 代码实现遵守 `.trellis/spec/architecture/local-first-sync-contract.md`。
* 设置页只消费 sync feature provider，不导入 DAO / repository / adapter。
* 数据库 schema 变更有迁移路径，并说明是否需要 Drift generated files。
* 回归测试覆盖 Good / Base / Bad case。
* 若实现过程中发现 sync contract 缺口，更新 `.trellis/spec/architecture/local-first-sync-contract.md`。

## Research Notes

### Relevant Specs

* `.trellis/spec/architecture/local-first-sync-contract.md`：定义 local-first、queue/status、merge policy、settings 只能读取状态快照。
* `.trellis/spec/architecture/system-boundaries.md`：要求 `presentation -> feature provider/controller -> repository/service -> DAO/client`，禁止 settings page 直接访问 DAO。
* `.trellis/spec/backend/database-guidelines.md`：涉及 Drift table / DAO / repository / sync 字段时必须保证迁移和仓储边界。
* `.trellis/spec/frontend/state-management.md`：设置页应读 feature-local provider，provider 放在 `features/<name>/data/providers.dart`。
* `.trellis/spec/frontend/quality-guidelines.md`：设置页视觉必须保持 Stitch 风格，避免默认 Material chrome 和阶段4运维膨胀。

### Code Patterns Found

* `lib/features/sync/data/sync_engine.dart`：同步入口负责 push / pull 编排，并在开始/完成时更新 `SyncStatusController`。
* `lib/features/sync/data/sync_codec.dart`：当前远端 envelope 解码、merge 决策和 repository apply 都集中在这里，是文本冲突检测的合理位置。
* `lib/features/sync/data/sync_status.dart`：已有 `SyncStatusState` / `SyncStatusRepository` / `SyncStatusController`，应扩展而不是另建 settings-only 状态。
* `lib/features/sync/data/providers.dart`：sync feature provider 的集中注册位置，settings UI 应从这里读。
* `lib/features/settings/presentation/bangumi_connection_section.dart`：已有 settings 区块消费 feature provider 的模式，可作为 Cloud Sync 面板参考。
* `test/features/sync/data/sync_engine_test.dart`：已有 push/pull、tombstone、localWins、push failure 的端到端测试骨架。
* `test/features/sync/data/sync_queue_status_test.dart`：已有 queue/status repository 测试，可补 provider 状态测试。

### Files Likely to Modify

* `lib/features/sync/data/sync_codec.dart`：检测 `userEntry` 文本字段冲突并触发冲突副本记录。
* `lib/features/sync/data/sync_conflict.dart`：新增 sync feature 内的冲突副本 repository / model。
* `lib/features/sync/data/providers.dart`：注册冲突 repository，并让 codec / UI 能消费统一状态。
* `lib/features/sync/data/sync_status.dart`：增加显式 conflict 标记入口，避免完成同步时覆盖 `hasConflicts`。
* `lib/shared/data/app_database.dart` 以及相关 Drift table / DAO / generated files：如果选择持久化冲突副本，需要 schema 变更。
* `lib/features/settings/presentation/settings_page.dart`：Cloud Sync 只读状态面板。
* `test/features/sync/data/sync_engine_test.dart`：文本冲突 + 标量 last-modified-wins 回归。
* `test/features/sync/data/sync_queue_status_test.dart`：状态 provider success / running / failure / conflict 回归。

### Feasible approaches

#### Approach A：持久化 `sync_conflict_entries` 表（推荐）

How it works:

* 新增 sync conflict copy 存储，记录 `notes` / `review` 本地与远端值。
* `SyncCodec.applyRemoteEnvelope(...)` 在应用远端快照前检测文本冲突。
* `SyncStatusController` 标记 `hasConflicts=true`。
* 设置页只读展示最小状态。

Pros:

* 符合“不能静默覆盖、必须保留副本”。
* App 重启后冲突仍可见，为阶段4合并 UI 保留数据基础。
* 测试可以直接验证副本内容。

Cons:

* 需要 DB schema 迁移。
* 需要处理 Drift generated files，环境不稳定时会成为实现风险。

#### Approach B：冲突副本写入 sync status 摘要 JSON

How it works:

* 不新增表，只在 sync status snapshot 中塞最小 conflict summary / JSON。

Pros:

* 改动小，不涉及新 DAO / generated files。

Cons:

* 只能表达摘要，很难可靠保留多个字段、多个实体的冲突副本。
* 阶段4做 diff / resolve 时大概率返工。
* 不满足“副本”语义的长期可追溯性。

#### Approach C：冲突时阻塞整个 `userEntry` apply，远端对象留在 queue / remote

How it works:

* 一旦 `notes` / `review` 冲突，整条远端 `userEntry` 不落库，只标记 conflict。

Pros:

* 最大限度避免覆盖本地文本。

Cons:

* 会破坏“标量字段仍按最后修改优先”的要求。
* 容易让 status / score 等非冲突字段长期不同步。
* 与现有 last-modified-wins merge policy 漂移较大。

## Recommended Technical Approach

推荐采用 **Approach A：持久化 `sync_conflict_entries` 表**。

关键设计：

* 冲突检测属于 sync feature，不属于 settings UI。
* 冲突副本是 append/upsert 型审计数据，不参与当前阶段的人工解决流程。
* `SyncCodec` 负责判断“是否存在文本冲突”，repository 负责记录副本。
* `SyncStatusController` 负责暴露 `hasConflicts`，settings 只读消费。
* 标量字段不因文本冲突改变既有 merge 策略。

## Decision (ADR-lite)

**Context**：`userEntry` 里的 `notes` / `review` 是用户可编辑文本，跨设备并发修改时最容易发生不可逆覆盖；但阶段3既有 sync merge 基线是 last-modified-wins，且 `status` / `score` 等标量字段不应被文本冲突阻塞。

**Decision**：当远端快照较新且 `notes` / `review` 发生文本冲突时，主记录当前值继续按 last-modified-wins 使用远端值；被覆盖侧文本必须写入冲突副本。反向场景同理：本地较新时本地主值保留，远端文本进入冲突副本。

**Consequences**：

* 保持现有 merge policy 一致，避免为 `userEntry` 引入“文本冲突阻塞整行”的特殊规则。
* `status`、`score` 等标量字段继续正常同步，不被 `notes` / `review` 冲突拖住。
* 阶段3用户只能看到“存在待处理冲突”，不能在 UI 内恢复或合并文本；恢复/合并能力留给阶段4或后续任务。
* 冲突副本必须持久化，否则主值覆盖后被覆盖侧文本不可恢复。

## Out of Scope

* 冲突 diff 查看器。
* 手动合并界面。
* 冲突解决 / 标记 resolved 的用户流程。
* 待同步明细列表。
* 手动重试中心。
* WebDAV / S3 连接表单。
* 完整阶段4同步运维面板。

## Implementation Plan

### PR1：冲突副本存储与测试

* 新增 sync conflict model / repository / DB schema。
* 补 `notes` / `review` 冲突副本测试。
* 验证 migration / generated files。

### PR2：合并流程接入

* 在 `SyncCodec.applyRemoteEnvelope(...)` 接入文本冲突检测。
* 保持 scalar last-modified-wins。
* 同步 `hasConflicts` 状态。

### PR3：设置页只读状态面板

* `Cloud Sync` 读取 sync status provider。
* 展示 current state / last sync / last failure / conflict。
* 补 provider / widget 或 smoke 测试。

## Technical Notes

### 依赖

* 依赖 `04-22-phase3-wp2-sync-engine-core`。
* 设置页落点：`lib/features/settings/presentation/settings_page.dart`。

### Validation Matrix

| Case | Expected behavior | Reject if |
| --- | --- | --- |
| local/remote `notes` both changed after sync baseline | conflict copy stores both values | one side disappears without copy |
| local/remote `review` both changed after sync baseline | conflict copy stores both values | one side disappears without copy |
| remote newer with score change and notes conflict | score follows remote, notes conflict copy retained | scalar field blocked by text conflict |
| local newer with notes conflict | local remains current, remote copy retained | stale remote overwrites local |
| sync running | settings shows running state | settings page remains static placeholder |
| sync failure | settings shows latest error summary | error only exists in logs |
| conflict exists | settings shows pending conflict | user cannot see conflict exists |

### Current correction note

本次流程应先完成本 PRD 与决策确认，再进入实现。任何已产生的实现 diff 都应视为未确认草稿，不能替代本 PRD 的确认过程。
