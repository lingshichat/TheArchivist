# 阶段3-WP4：S3-compatible 适配器

## Goal

按阶段3父任务约定，实现一套可复用的 `S3-compatible` storage adapter，复用现有 `SyncStorageAdapter` contract，让 WP2 的同步引擎无需改接口即可接入基于 bucket/object 的远端存储。

## Requirements

### R1 对齐统一 adapter contract

必须严格实现阶段3统一 `SyncStorageAdapter` contract：

* `listRecords()`
* `readText(...)`
* `writeText(...)`
* `writeTombstone(...)`
* `delete(...)`

不允许单独做第二套 S3 专用引擎接口。

### R2 最小能力

至少支持：

* 认证 / 连接
* 列举对象
* 读取对象
* 写入对象
* 删除对象或写 tombstone

### R3 兼容 S3-compatible

适配器不能绑死某一家云厂商私有 SDK 或控制面能力，必须只依赖通用 S3-compatible object API：

* `ListObjectsV2`
* `GetObject`
* `PutObject`
* `DeleteObject`

不包含：

* bucket 创建
* lifecycle / policy 管理
* multipart upload
* presigned URL

### R4 配置与寻址边界

适配器配置必须能表达通用 S3-compatible 所需的最小连接参数：

* `endpoint`
* `region`
* `bucket`
* `rootPrefix`
* `accessKey`
* `secretKey`
* optional `sessionToken`
* `addressingStyle`

其中：

* `bucket` / `rootPrefix` / `endpoint` 等传输细节由 adapter 吞掉，不泄漏到 UI 或 engine
* 远端对象布局仍然必须复用统一 `entities/...` 与 `tombstones/...`
* addressing style 需要由配置决定，不能把 bucket host 规则写死在代码里

### R5 请求签名与分页

* 认证必须走 `Signature Version 4`
* `listRecords()` 需要吞掉 `ListObjectsV2` 的分页细节，直到拿到完整远端对象集合
* object key、query parameter 与 signed path 的编码方式必须保持一致，避免列举成功但读写签名不一致

### R6 错误映射

需要把底层 HTTP / signing / I/O 错误映射为同步域错误：

* 网络失败
* 认证失败
* 对象不存在
* 服务端失败

并保持：

* adapter 对外只抛 `SyncException` 体系
* 不把原始 transport exception 泄漏给 engine / UI

### R7 测试

至少覆盖：

* 正常 list / read / write / delete
* `tombstone` 写入
* `401 / 403`
* `404`
* `5xx`
* 桶或前缀为空时的列举行为
* `ListObjectsV2` 分页
* 重复写入覆盖或重复删除幂等行为

## Acceptance Criteria

* [ ] `S3StorageAdapter` 复用统一 `SyncStorageAdapter` contract
* [ ] `list / read / write / delete / tombstone` 能在 S3-compatible 目标上走通
* [ ] 实现只依赖通用 object API，不绑定厂商私有语义
* [ ] request signing 使用 `SigV4`
* [ ] `ListObjectsV2` 分页不会导致只读到前 1000 条对象
* [ ] 错误被映射为同步域错误，而不是原始 transport error
* [ ] fake 或 mock 测试覆盖关键成功 / 失败路径
* [ ] 不需要改引擎即可被 WP2 接入

## Definition of Done

* 新增或更新的 adapter / transport 测试能覆盖成功路径与关键失败路径
* `flutter analyze lib test` 通过
* `flutter test` 通过
* 相关 `spec` 补齐 S3 transport / adapter 约束
* 不把新的 durable contract 只留在本子任务 PRD

## Technical Approach

### 模块落点

* `lib/shared/network/s3_api_client.dart`
  * S3 transport client
  * 负责请求拼装、SigV4 签名、raw response、typed transport error
* `lib/features/sync/data/s3_storage_adapter.dart`
  * 实现 `SyncStorageAdapter`
  * 负责 bucket / prefix / object key 到统一 sync key 的转换
* `lib/features/sync/data/providers.dart`
  * 暴露 S3 client / adapter provider
* `test/features/sync/data/s3_storage_adapter_test.dart`
  * 覆盖成功路径、分页、错误映射与幂等行为

### 实现策略

采用 **custom `Dio` transport + `aws_signature_v4` signer**，而不是直接把第三方 S3 SDK 塞进 adapter。

原因：

* 仓库当前已经稳定使用 `Dio` + interceptor + typed exception
* WP3 WebDAV 已经给出了 transport/client 与 adapter 分层样板
* 这样可以让 S3 与 WebDAV 在 provider、测试、错误边界上保持对称

## Research Notes

### 已有基础

* WP2 的 `SyncEngine` 已经稳定依赖 `SyncStorageAdapter`
* WP3 的 `WebDavStorageAdapter` 已经验证了 transport-only adapter 的结构可行
* 现有仓库没有 S3 SDK 或 SigV4 signer 依赖，需要在 WP4 明确选择

### 外部研究结论

* AWS 官方文档要求现代 S3 REST 请求使用 `Signature Version 4`
* `ListObjectsV2` 单次最多返回 1000 条，需要处理 `ContinuationToken`
* AWS 官方同时支持 `path-style` 与 `virtual-hosted-style`
* `aws_signature_v4` 提供 Flutter/VM 可用的 SigV4 signer
* `minio` 包可覆盖对象 API，但它是 unofficial package

### 可行方案

**Approach A：custom `Dio` transport + `aws_signature_v4` signer**（Recommended）

* 优点：
  * 与现有 WebDAV 模式一致
  * 更容易复用当前 mock 测试和 typed error 约束
* 缺点：
  * 需要自己处理 XML 解析、分页和 path builder

**Approach B：wrap `minio` package behind adapter**

* 优点：
  * 对象 API 相对现成
* 缺点：
  * 不符合当前 transport/client 分层风格
  * unofficial package 带来额外维护和行为不透明风险

**Approach C：handwrite SigV4**

* 优点：
  * 依赖最少
* 缺点：
  * 签名细节易错，超出 WP4 必要范围

## Decision (ADR-lite)

**Context**

阶段3已经有统一 sync engine 和 WebDAV adapter 样板，但还没有 S3-compatible transport 约束。WP4 既要兼容通用 S3 object API，又不能把整个同步层改成另一套 SDK 风格。

**Decision**

1. 新增 `S3ApiClient` 放在 `lib/shared/network/`
2. 新增 `S3StorageAdapter` 放在 `lib/features/sync/data/`
3. 使用 `SigV4` 进行请求签名
4. 保持 adapter 只实现 storage contract，不处理 merge / repository / UI 状态
5. 把分页、bucket/key/prefix/addressing style 都封装在 transport + adapter 内部

**Consequences**

* S3 与 WebDAV 将共享同一层级结构，更利于阶段4设置页接入
* 需要额外补一层 S3 transport 和签名测试
* 不能直接偷用整包 SDK，但能换来更稳定的 repo 一致性

## Out of Scope

* 设置页表单
* 连接测试按钮
* 冲突处理
* 重试面板
* bucket 自动创建
* multipart upload
* presigned URL

## Implementation Plan

* PR1：
  * 增补 PRD / research / spec
  * 冻结 S3 config、addressing style、SigV4、分页规则
* PR2：
  * 新增 `S3ApiClient`
  * 新增 `S3StorageAdapter`
  * 在 `providers.dart` 暴露 S3 provider
* PR3：
  * 新增 adapter 测试
  * 校验错误映射、分页和幂等行为

## Technical Notes

### 依赖

* 依赖 `04-22-phase3-wp1-sync-model-queue`
* 接口联调依赖 `04-22-phase3-wp2-sync-engine-core`
* 参考 `04-22-phase3-wp3-webdav-adapter`

### 重点文件

* `lib/features/sync/data/sync_storage_adapter.dart`
* `lib/features/sync/data/sync_engine.dart`
* `lib/features/sync/data/webdav_storage_adapter.dart`
* `lib/features/sync/data/providers.dart`
* `lib/shared/network/webdav_api_client.dart`
* `test/features/sync/data/webdav_storage_adapter_test.dart`
