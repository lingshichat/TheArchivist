# 阶段3-WP1：同步对象模型与本地队列

## Goal

把阶段3最底层的同步骨架先搭起来：

* 持久化设备身份
* 定义同步实体快照模型
* 建立本地待同步队列与最小运行状态
* 给后续增量引擎、WebDAV、S3 适配器提供统一 contract

## Requirements

### R1 持久化设备身份

* `DeviceIdentityService` 需要从“只会生成 UUID”升级为“可稳定读写当前设备 ID”
* repository 不再返回空字符串 deviceId
* 所有同步相关写入必须能拿到稳定 deviceId

### R2 同步 feature 模块落点

新增 `lib/features/sync/data/`，至少包含：

* 同步实体类型定义
* 同步快照 DTO / envelope
* 同步队列模型
* 同步状态模型
* feature-local providers

### R3 本地同步队列

首版至少支持：

* 记录待上传对象
* 记录对象类型、对象 ID、操作类型、最近尝试时间、失败摘要、重试次数
* 允许按批次取出待执行项
* 支持成功后清除或标记完成

### R4 变更扫描与最小增量判定

首版本地变更扫描规则至少支持：

* `lastSyncedAt == null`
* `updatedAt > lastSyncedAt`
* `deletedAt != null`

`syncVersion` 可以保留为长期字段，但首版不要求先把全仓储的递增语义全部做完。

### R5 repository 基础补齐

至少补齐这些基础能力：

* `ProgressRepository`
  * remote apply / markSynced 落点
* `TagRepository`
  * 支持同步 attach/detach 结果的 repository 入口
* `ShelfRepository`
  * 支持同步 attach/detach 结果的 repository 入口

### R6 最小运行状态

本地需要能记录：

* 是否正在同步
* 最近同步时间
* 最近一次失败摘要
* 待同步数量

完整重试中心与运维面板不在本 WP。

## Acceptance Criteria

* [ ] 当前设备 ID 可持久化读取，repository 不再写空字符串 deviceId
* [ ] 新增 `lib/features/sync/data/`，包含 sync model / queue / status / provider 基础结构
* [ ] 本地待同步队列可以入队、取批、标记完成、记录失败摘要
* [ ] 本地变更扫描能识别新增、更新、软删除三类对象
* [ ] `ProgressRepository` / `TagRepository` / `ShelfRepository` 至少具备后续同步可复用的写回入口
* [ ] 阶段3后续 WP 不需要自己再发明第二套 deviceId / queue / status contract
* [ ] `flutter analyze lib test` 通过
* [ ] 相关单元测试通过

## Technical Approach

### 推荐落点

* `lib/features/sync/data/`
  * `sync_models.dart`
  * `sync_queue.dart`
  * `sync_status.dart`
  * `providers.dart`
* `lib/shared/data/`
  * 补设备身份存储与 repository 写回入口

### 推荐做法

* 队列模型保持 storage-agnostic，不提前耦合 WebDAV / S3 细节
* 统一把“对象类型 + 对象 ID + 操作 + 时间戳 + 错误摘要”当成队列最小单元
* repository 仍负责业务表写入与同步字段 stamping，不把这些逻辑丢给 UI 或 adapter

## Out of Scope

* 真实远端 push / pull
* WebDAV / S3 请求实现
* 冲突副本 UI
* 设置页同步表单

## Technical Notes

### 相关文件

* `lib/shared/data/device_identity.dart`
* `lib/shared/data/sync_stamp.dart`
* `lib/shared/data/repositories/media_repository.dart`
* `lib/shared/data/repositories/user_entry_repository.dart`
* `lib/shared/data/repositories/progress_repository.dart`
* `lib/shared/data/repositories/tag_repository.dart`
* `lib/shared/data/repositories/shelf_repository.dart`

### 主要风险

* 当前 deviceId 为空字符串，必须先修
* 如果队列 contract 先写死某个远端协议，后面 WebDAV / S3 会分叉
