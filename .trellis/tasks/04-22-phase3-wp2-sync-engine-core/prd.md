# 阶段3-WP2：增量上传与拉取引擎

## Goal

在 WP1 的队列与模型之上，打通跨设备同步的核心编排：

* 增量上传
* 增量拉取
* 本地优先合并
* 成功后回写同步戳
* 失败后保留本地状态并输出 summary

## Requirements

### R1 统一编排入口

需要一个统一同步编排入口，例如：

* `SyncCoordinator`
* `SyncEngine`

它负责：

* 拉起一轮 sync
* 串联 push / pull
* 汇总 summary
* 写回最小状态

### R2 本地上传

上传路径至少支持：

* 从本地队列或变更扫描中取待同步对象
* 序列化为统一同步快照
* 调 adapter 写到远端
* 成功后回写 `lastSyncedAt`
* 失败后保留本地数据并记录失败摘要

### R3 远端拉取

拉取路径至少支持：

* 列举远端对象或变更
* 读取对象快照
* 映射到本地 repository 写回入口
* 按 local-first 规则合并
* 返回批次 summary

### R4 合并范围

阶段3首版至少覆盖：

* 状态
* 评分
* 进度
* 列表关联
* 标签关联

文本冲突副本落到 WP5。

### R5 错误模型

需要 typed error，至少区分：

* 连接失败
* 认证失败
* 远端对象缺失
* 数据格式错误
* 部分批次失败

不允许用裸 `Exception('sync failed')` 当公共错误语义。

### R6 测试闭环

至少用 fake adapter 跑通：

* 新增对象上传
* 干净对象拉取覆盖
* 本地脏数据保留
* 删除事件传播
* 失败不回滚本地数据

## Acceptance Criteria

* [ ] 有统一 sync engine / coordinator 入口
* [ ] 能用 fake adapter 跑通 push / pull 最小闭环
* [ ] 成功路径会回写相关对象的 `lastSyncedAt`
* [ ] 失败路径不会回滚本地已提交数据
* [ ] status / score / progress / list / tag 可以参与同步
* [ ] local-first 冲突规则在 engine 层明确，不下沉到 adapter
* [ ] 同步结果能输出 summary 给 WP5 消费
* [ ] `flutter analyze lib test` 通过
* [ ] 相关单元测试通过

## 调研结论

### 当前起点

WP1 已经把这几块基础设施落地到代码：

* `lib/features/sync/data/sync_models.dart`
  * 已有 `SyncEntityEnvelope` / `SyncChangeCandidate`
* `lib/features/sync/data/sync_queue.dart`
  * 已有 dirty scan、队列去重、尝试记录、完成标记
* `lib/features/sync/data/sync_status.dart`
  * 已有最小状态快照与 controller
* `lib/shared/data/device_identity.dart`
  * 已有稳定 `deviceId` 持久化
* `lib/shared/data/repositories/progress_repository.dart`
* `lib/shared/data/repositories/tag_repository.dart`
* `lib/shared/data/repositories/shelf_repository.dart`
  * 已有 remote apply / `markSynced(...)` 级别的写回入口

当前代码里还缺这几块，因此它们应收敛到 WP2：

* 统一 `SyncEngine` / `SyncCoordinator`
* 统一 storage adapter contract
* 远端对象 key / envelope 布局
* push / pull summary
* typed sync error
* `SyncEntityEnvelope` 与 repository 写回入口之间的编解码桥接
* fake adapter 驱动的端到端引擎测试

### 关键缺口

* `lib/features/sync/data/` 里还没有 engine / adapter / exception / summary 文件
* `SyncEntityEnvelope` 目前只被队列测试覆盖，还没有真正串到 push / pull 流程
* `lib/features/settings/presentation/settings_page.dart` 的 `Cloud Sync` 仍是静态占位
* `lib/shared/data/repositories/activity_log_repository.dart` 还没有 remote apply / markSynced；活动日志可先保留在模型层，不纳入本 WP 首版验收

## 任务边界

### 本任务负责

* 把 WP1 的队列、状态、设备身份真正接到一轮可执行的 sync orchestration
* 定义统一 storage adapter contract，供 WP3 / WP4 直接复用
* 定义远端对象 envelope / key 布局与批次 summary
* 定义 typed sync error 与失败摘要收敛方式
* 打通这些对象的 push / pull / apply / `markSynced(...)`
  * `mediaItem`
  * `userEntry`
  * `progressEntry`
  * `tag`
  * `shelf`
  * `mediaItemTag`
  * `mediaItemShelf`
* 用 fake adapter 跑通最小闭环测试

### 父任务负责

父任务 `04-19-phase3-sync-engine` 继续作为这些长期契约的唯一来源：

* local-first 原则
* sync 字段集合与 ownership
* 冲突总策略
* adapter 只是存储/传输边界
* 阶段3整体验收与子任务顺序

如果 WP2 研发中发现这些长期契约需要改，必须先回写父任务 PRD 与相关 `spec/architecture/`，不能只改本 PRD。

### 不属于本任务

* 真实 WebDAV transport 实现
* 真实 S3-compatible transport 实现
* 冲突副本持久化与可见性
* 设置页最小状态面板
* 连接表单、手动重试、完整运维 UI
* 活动日志的完整跨设备同步写回

## 与后续任务的接口边界

### 对 WP3 / WP4 的交付

WP2 必须先冻结下面这些接口，后续适配器只实现 transport：

* storage adapter 抽象
* 远端对象 key / tombstone 布局
* list / read / write / delete 输入输出模型
* typed sync error 基类与映射目标
* 引擎调用适配器的时序

### 对 WP5 的交付

WP5 直接消费 WP2 产出的：

* sync summary
* 最小状态更新时机
* `hasConflicts` / `lastErrorSummary` 等状态位
* pull / merge 阶段预留的冲突信号

WP5 不再回头定义第二套状态模型或错误模型。

### 后续任务

1. **本任务内后续步骤**
   * 先冻结 adapter contract / envelope 布局 / error model
   * 再补实体序列化与 apply bridge
   * 再落 push / pull orchestration
   * 最后补 fake adapter 测试
2. **任务树后续**
   * `04-22-phase3-wp3-webdav-adapter`
   * `04-22-phase3-wp4-s3-adapter`
   * `04-22-phase3-wp5-conflict-status`
3. **潜在后补项**
   * 如果阶段3后面确认活动日志也要真正跨设备同步，应先在父任务补明确交付，再决定是否拆新子任务；不直接塞进 WP2

## Technical Approach

### 推荐结构

* `lib/features/sync/data/sync_engine.dart`
* `lib/features/sync/data/sync_summary.dart`
* `lib/features/sync/data/sync_exception.dart`
* `lib/features/sync/data/sync_merge_policy.dart`
* `lib/features/sync/data/sync_storage_adapter.dart`
* `lib/features/sync/data/sync_codec.dart`

### 推荐复用

* 批量 pull / summary 模式复用 `BangumiCollectionPullService`
* 成功后 `markSynced(...)` 模式复用 `BangumiCollectionSyncService`
* 最小状态回写模式复用 `BangumiSyncStatusController`

### 推荐落地顺序

* 先定义 engine 依赖的抽象与 DTO，再开始写 transport / orchestration
* 先把 repository 写回入口串成 codec / apply bridge，再接 push / pull 主链路
* fake adapter 测试先覆盖核心对象类型与失败摘要，不提前耦合 WebDAV / S3 细节

## Out of Scope

* 真实 WebDAV / S3 客户端
* 连接测试 UI
* 冲突查看界面
* 手动重试列表 UI

## Technical Notes

### 依赖

* 依赖 `04-22-phase3-wp1-sync-model-queue`

### 主要风险

* 如果 engine 直接依赖具体 WebDAV / S3 细节，后面无法并行接两个 adapter
* 如果只同步 media / user entry，不补 progress/tag/shelf，会和阶段3验收标准不一致
* 如果 WP2 不先冻结 adapter contract，WP3 / WP4 会各自长出一套接口
* 如果不先定义 codec / apply bridge，现有 `SyncEntityEnvelope` 只能停留在模型层，无法形成真实闭环
