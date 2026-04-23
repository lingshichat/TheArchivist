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

## Technical Approach

### 推荐结构

* `lib/features/sync/data/sync_engine.dart`
* `lib/features/sync/data/sync_summary.dart`
* `lib/features/sync/data/sync_exception.dart`
* `lib/features/sync/data/sync_merge_policy.dart`

### 推荐复用

* 批量 pull / summary 模式复用 `BangumiCollectionPullService`
* 成功后 `markSynced(...)` 模式复用 `BangumiCollectionSyncService`
* 最小状态回写模式复用 `BangumiSyncStatusController`

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
