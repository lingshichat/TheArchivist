# 阶段4：设置、备份恢复与同步运维

## 目标

把同步能力从“能跑”收成“能配、能看、能修”。

本阶段让用户不用开发者手动排查，也能完成：

* 配置跨端同步目标
* 测试连接是否可用
* 导出 / 导入本地快照包
* 查看待同步项目并重试
* 查看文本冲突副本

## 校准记录

校准日期：2026-04-24

* 阶段2与阶段3已完成，当前任务可以进入阶段4实现
* 阶段3已提供最小同步状态面板，阶段4不重复实现该面板
* Bangumi 进度同步已拆到 `04-24-followup-bangumi-progress-sync`
* 当前任务只承接同步配置、连接测试、备份导入导出、待同步重试和冲突副本查看

## 父任务边界

本阶段继续遵守根父任务的长期边界：

* 本地数据库是运行时主数据源
* WebDAV / S3-compatible 只是传输和存储目标
* 日常跨设备同步走对象 / 日志增量
* 快照包只用于备份恢复，不用于日常自动同步
* 远端同步失败不回滚本地写入
* 文本字段冲突必须保留冲突副本
* Bangumi 外部平台同步不和跨端设备同步混在一起

## 范围

### R1 同步目标配置

设置页提供跨端同步配置入口。

支持两类目标：

* `WebDAV`
* `S3-compatible`

配置要求：

* 可选择当前启用目标类型
* 可保存 WebDAV `baseUri`、`username`、`password`、`rootPath`
* 可保存 S3-compatible `endpoint`、`region`、`bucket`、`rootPrefix`、`accessKey`、`secretKey`、`sessionToken`、`addressingStyle`
* 凭据不能写入普通日志、activity log 或用户可复制的错误详情
* 凭据优先沿用 `flutter_secure_storage`，和现有 Bangumi token / device id 存储方式保持一致
* 页面层只调用 controller / provider，不直接创建 transport client

### R2 连接测试

用户保存配置前或保存后，可以执行连接测试。

测试策略：

* 用当前表单配置构造对应 adapter
* 写入一个可逆的 probe 对象
* 读取 probe 内容确认一致
* 删除 probe 对象
* 失败时映射为用户可读摘要，不暴露原始密钥、token、签名串或完整请求体

建议 probe key：

```text
.probe/<deviceId>.json
```

连接测试不应触发完整 `SyncEngine.runSync(...)`。

### R3 手动同步入口与失败重试

设置页提供手动同步入口。

行为要求：

* 使用已保存的同步目标配置创建 adapter
* 调用现有 `SyncEngine.runSync(...)`
* 运行中禁用重复触发
* 成功后刷新最小同步状态
* 失败后保留队列条目，并展示摘要
* 本地数据不回滚

待同步列表要求：

* 展示 `SyncQueueRepository.listPending(...)` 结果
* 至少展示实体类型、操作、重试次数、最近尝试时间、错误摘要
* 支持重试单条或触发一次全量重试
* 不允许页面直接查询 DAO

### R4 冲突副本查看

设置页或独立同步运维区展示文本冲突副本。

数据来源：

* `SyncConflictRepository.listPending()`

展示要求：

* 显示实体类型、字段名、检测时间
* 显示本地值与远端值的摘要
* 说明当前版本需要用户人工处理

本阶段可以只做查看。
手动合并、选择本地/远端、标记已解决可以作为后续增强。

### R5 快照包导出

设置页 `Export Backup` 按钮接入真实导出逻辑。

快照包建议采用版本化 JSON，不直接复制 SQLite 数据库文件。

导出内容：

* `mediaItem`
* `userEntry`
* `progressEntry`
* `tag`
* `shelf`
* `mediaItemTag`
* `mediaItemShelf`
* `activityLog`

导出格式建议复用 `SyncEntityEnvelope` 的字段语义：

```json
{
  "format": "record-anywhere.snapshot",
  "version": 1,
  "exportedAt": "2026-04-24T00:00:00.000Z",
  "deviceId": "<current-device-id>",
  "entities": []
}
```

导出必须过滤或处理敏感信息：

* 不导出 Bangumi access token
* 不导出 WebDAV password
* 不导出 S3 secret key / session token
* 不导出设备 secure storage 内部密钥

### R6 快照包导入

设置页 `Import Archive` 按钮接入真实导入逻辑。

导入策略：

* 先解析并校验 `format` / `version`
* 按依赖顺序导入实体
* 复用现有 sync codec / repository 的 remote apply 语义
* 默认采用合并恢复，不做整库硬覆盖
* 文本冲突继续保留冲突副本
* 导入失败不应清空现有本地库

导入结果需要返回摘要：

* 已应用数量
* 跳过数量
* 冲突数量
* 失败数量
* 首个失败摘要

## 不包含

* 多账号体系
* 复杂团队协作运维能力
* Bangumi 进度同步
* Bangumi 私人笔记 / 标签 / 列表同步
* 远端删除联动
* 整库 SQLite 文件覆盖式恢复
* 冲突内容的复杂 diff / merge 编辑器
* 自动后台定时同步调度

## 前置依赖

* 依赖 `04-19-phase2-bangumi-flow`
* 依赖 `04-19-phase3-sync-engine`

当前已确认：

* `04-19-phase2-bangumi-flow` 已归档完成
* `04-19-phase3-sync-engine` 已归档完成
* 当前任务可直接基于现有 sync engine、queue、status、adapter、conflict copy 继续实现

## Relevant Specs

架构  `.trellis/spec/architecture/system-boundaries.md`
      约束设置页不能直接操作 DAO / transport client，配置、测试、重试要走 feature controller / provider

架构  `.trellis/spec/architecture/local-first-sync-contract.md`
      约束本地优先、队列重试、adapter 边界、冲突副本和快照包边界

架构  `.trellis/spec/architecture/task-spec-governance.md`
      约束 Phase4 共享规则必须落在阶段 PRD 或 spec，不能散在子任务里

后端  `.trellis/spec/backend/directory-structure.md`
      约束 non-UI 代码放在 `features/sync/data`、`shared/data`、`shared/network`

后端  `.trellis/spec/backend/database-guidelines.md`
      约束 Drift 表、软删除、同步字段、raw SQL 绑定和备份恢复边界

后端  `.trellis/spec/backend/error-handling.md`
      约束 `SyncException` typed error、队列重试、批量失败摘要和 local-first 错误策略

后端  `.trellis/spec/backend/logging-guidelines.md`
      约束不要记录 token、password、secret key、私人笔记原文和 raw payload

前端  `.trellis/spec/frontend/design-system.md`
      约束 Settings 页面保持 Stoa Editorial 风格，不回退默认 Material 管理台

前端  `.trellis/spec/frontend/state-management.md`
      约束表单状态、异步状态、按钮 pending 状态和 provider 归属

前端  `.trellis/spec/frontend/network-guidelines.md`
      约束 WebDAV / S3 transport client 不泄漏到 UI 层

指南  `.trellis/spec/guides/cross-layer-thinking-guide.md`
      本任务横跨 UI、provider、secure storage、adapter、engine、DB，需要先固定数据流

指南  `.trellis/spec/guides/code-reuse-thinking-guide.md`
      连接测试、adapter config、snapshot envelope 应优先复用已有 sync 结构

## Code Patterns Found

设置  `lib/features/settings/presentation/settings_page.dart`
      已有 `Local Data`、`Cloud Sync` 区块；`Export Backup` / `Import Archive` 目前是空回调；`Cloud Sync` 只读展示最小状态

同步  `lib/features/sync/data/providers.dart`
      已有 queue、status、conflict、codec、engine、WebDAV / S3 adapter provider

同步  `lib/features/sync/data/sync_engine.dart`
      已有完整 `push -> pull -> summary -> status` 编排入口

同步  `lib/features/sync/data/sync_queue.dart`
      已有本地 dirty scan、pending queue、retry count、error summary、completedAt

同步  `lib/features/sync/data/sync_status.dart`
      已有最小状态快照和 `SyncStatusController`

同步  `lib/features/sync/data/sync_conflict.dart`
      已有文本冲突副本落库和 `listPending()`

同步  `lib/features/sync/data/sync_codec.dart`
      已有 `SyncEntityEnvelope` 编码、远端 apply、merge policy、mark synced 入口

适配  `lib/features/sync/data/webdav_storage_adapter.dart`
      已有 WebDAV list/read/write/delete/tombstone，并会自动创建父级 collection

适配  `lib/features/sync/data/s3_storage_adapter.dart`
      已有 S3-compatible list/read/write/delete/tombstone，支持 path-style 与 virtual-hosted-style

网络  `lib/shared/network/webdav_api_client.dart`
      已有 WebDAV transport client 和 typed error 映射

网络  `lib/shared/network/s3_api_client.dart`
      已有 S3 SigV4 request builder 和 typed error 映射

数据库  `lib/shared/data/app_database.dart`
      当前 `schemaVersion = 3`，sync conflict table 用 raw SQL 创建

## Research Notes

### 已有基础

* 同步引擎、队列、状态、冲突副本、WebDAV adapter、S3 adapter 已就绪
* Settings 页面已有可承接 Phase4 的区块结构
* `flutter_secure_storage` 已用于 Bangumi token 与 device id，可复用到同步目标凭据
* `path_provider` 已存在，可用于导出默认文件位置或后续文件选择落点
* `SyncEntityEnvelope` 已覆盖快照包需要的大部分实体表达

### 当前缺口

* 没有同步目标持久化模型或 store
* 没有设置页表单 controller
* 没有连接测试 service
* 没有手动同步按钮接入已保存配置
* 没有待同步列表 UI
* `SyncConflictRepository` 只有 `listPending()`，没有 resolve / mark reviewed
* `Export Backup` / `Import Archive` 仍是空回调
* `pubspec.yaml` 目前没有 `file_picker`、`share_plus`、`archive` 这类文件选择 / 压缩依赖

### 推导结论

* 第一轮实现应先落同步目标配置与连接测试，再接手动同步和列表
* 备份包首版用 JSON 文件即可，不必引入 zip 压缩
* 导入首版应采用合并恢复，不做整库覆盖
* 冲突副本首版只看不合并，避免引入复杂编辑器
* 页面层必须保持薄，只读 provider 状态并调用 controller

## Cross-layer Flow

```text
[Phase4] ──┬── 目标配置 ──┬── Settings 表单
           │              └── Secure storage 持久化
           ├── 连接测试 ──┬── Adapter probe
           │              └── typed summary
           ├── 手动同步 ──┬── SyncEngine.runSync
           │              └── SyncStatus 更新
           ├── 运维查看 ──┬── SyncQueue pending
           │              └── Conflict copies
           └── 快照恢复 ──┬── JSON snapshot export
                          └── merge import
```

### 目标配置链路

```text
SettingsPage
  -> SyncTargetController
  -> SyncTargetStore
  -> flutter_secure_storage
  -> webDavStorageAdapterProvider / s3StorageAdapterProvider
```

### 手动同步链路

```text
SettingsPage
  -> SyncOperationsController
  -> SyncTargetStore.readActive()
  -> adapter provider
  -> SyncEngine.runSync(adapter)
  -> SyncStatusController + SyncQueueRepository
```

### 快照导入链路

```text
Snapshot JSON
  -> SnapshotService.parse
  -> SyncEntityEnvelope
  -> SyncCodec.applyRemoteEnvelope
  -> repositories
  -> Drift
```

## Implementation Plan

### WP1：同步目标配置与连接测试

* 新增 `SyncTargetConfig` / `SyncTargetStore`
* 新增 settings 表单状态与 controller
* 接入 WebDAV / S3-compatible 配置保存
* 实现 probe-based connection test
* 增加配置与连接测试单元测试

### WP2：手动同步与待同步列表

* 从保存的 active target 构造 adapter
* 设置页接 `SyncEngine.runSync(...)`
* 展示 pending queue 列表
* 支持手动重试
* 增加 pending / retry / failure tests

### WP3：冲突副本查看

* 展示 `SyncConflictRepository.listPending()`
* 显示本地 / 远端文本摘要
* 展示人工处理提示
* 首轮不做 merge 编辑器

### WP4：快照包导出与导入

* 新增 `SnapshotService`
* 导出版本化 JSON 快照
* 导入时校验格式并合并恢复
* 复用 `SyncEntityEnvelope` / `SyncCodec`
* 增加 round-trip 和坏包测试

## Acceptance Criteria

### 功能验收

* [ ] 设置页可配置并保存 WebDAV 同步目标
* [ ] 设置页可配置并保存 S3-compatible 同步目标
* [ ] 同步目标支持连接测试
* [ ] 连接测试成功后不留下用户可见的脏同步对象
* [ ] 可手动触发一次跨设备同步
* [ ] 同步运行中禁止重复触发
* [ ] 可查看待同步项目
* [ ] 可查看失败摘要和重试次数
* [ ] 可手动重试失败同步
* [ ] 可查看冲突副本并知道需要人工处理
* [ ] 可手动导出快照包
* [ ] 可手动导入快照包并得到摘要

### 数据验收

* [ ] WebDAV / S3 密钥不进入普通日志、activity log 或导出快照
* [ ] 快照包不包含 Bangumi token、WebDAV password、S3 secret key
* [ ] 导入坏格式文件时不修改本地库
* [ ] 导入快照时按 local-first / merge policy 处理
* [ ] 文本冲突导入后仍保留冲突副本

### 架构验收

* [ ] `presentation/` 不 import DAO、`dio`、WebDAV / S3 transport client
* [ ] 同步目标配置 provider 留在 `features/sync/data`
* [ ] transport client 仍只在 `shared/network`
* [ ] adapter 不承担 merge / UI 状态逻辑
* [ ] 日常跨设备同步仍走对象 / 日志增量
* [ ] 快照包没有替代自动同步链路

### 质量验收

* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过
* [ ] 同步目标 store 有单元测试
* [ ] 连接测试有 WebDAV / S3 adapter fake 测试
* [ ] 快照导入导出有 round-trip 测试
* [ ] pending queue / retry UI 至少有 widget 或 controller 覆盖

## 风险与取舍

* 快照导入选择合并恢复，不做整库覆盖，避免误删本地数据
* 冲突副本首轮只查看，不做复杂合并，避免阶段4范围膨胀
* 文件选择能力如果需要新依赖，必须同步更新 `pubspec.yaml` 和平台测试说明
* 若后续需要压缩包格式，再引入 zip；当前 PRD 先用版本化 JSON 收口
