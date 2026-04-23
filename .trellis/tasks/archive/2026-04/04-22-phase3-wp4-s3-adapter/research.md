# 阶段3-WP4：S3-compatible 适配器 Research

## Relevant Specs

- `.trellis/spec/architecture/local-first-sync-contract.md`
  - `S3-compatible` 只能实现 `SyncStorageAdapter`
  - 远端对象布局必须继续复用 `entities/...` 与 `tombstones/...`
- `.trellis/spec/architecture/system-boundaries.md`
  - transport client 放 `lib/shared/network/`
  - feature provider / adapter 放 `lib/features/sync/data/`
- `.trellis/spec/backend/directory-structure.md`
  - transport config 在 `shared/network`
  - integration-specific provider 在 feature data
- `.trellis/spec/backend/error-handling.md`
  - transport 错误必须映射成 typed error
  - auth 失败需要和普通 server/network 失败分开
- `.trellis/spec/backend/quality-guidelines.md`
  - service/client 隐藏传输细节
  - 不把 transport 细节和原始异常泄漏到 engine / UI
- `.trellis/spec/frontend/network-guidelines.md`
  - 已有 WebDAV transport 场景，可直接复用 client → adapter → engine 的分层模式

## Code Patterns Found

- `lib/features/sync/data/sync_storage_adapter.dart`
  - WP4 必须严格实现现有五个方法，不能再发明第二套接口
- `lib/features/sync/data/sync_engine.dart`
  - engine 只依赖 `list/read/write/delete/tombstone` 五类能力
  - adapter 需要自己吞掉分页、认证、对象路径和错误映射
- `lib/shared/network/webdav_api_client.dart`
  - 已有 `Dio` + typed exception + header injection 的 transport 样板
- `lib/features/sync/data/webdav_storage_adapter.dart`
  - 已有 transport-only adapter 样板，可直接镜像出 S3 的结构、日志和异常边界
- `lib/features/sync/data/providers.dart`
  - 现有 sync feature provider 出口已经放好，WP4 只需在同文件补 S3 client / adapter provider
- `test/features/sync/data/webdav_storage_adapter_test.dart`
  - 已有 list/read/write/delete/tombstone、401/404/5xx、幂等路径的 mock 测试样板

## External Research

### Official protocol / package findings

- AWS S3 REST 请求在现代区域默认应使用 `Signature Version 4`
- `ListObjectsV2` 单次最多返回 1000 个对象，需要处理 `ContinuationToken`
- `ListObjectsV2` 即使 `200 OK` 也可能返回需要防御式解析的 XML
- AWS 官方同时描述了 `path-style` 与 `virtual-hosted-style` 两种对象访问方式
- `aws_signature_v4` 是 `aws-amplify.com` 发布的 Dart/Flutter SigV4 signer
- `minio` 包能覆盖 `listObjectsV2 / getObject / putObject / removeObject`，但它是 unofficial package

### Feasible approaches here

**Approach A: custom `Dio` transport + `aws_signature_v4` signer**（Recommended）

- How it works:
  - 新增 `lib/shared/network/s3_api_client.dart`
  - 仍用 `Dio` 负责请求、mock 和错误拦截
  - 用 `aws_signature_v4` 做 SigV4 签名
  - `S3StorageAdapter` 只负责 bucket/key/prefix 到统一 contract 的翻译
- Pros:
  - 和现有 `WebDavApiClient` / `WebDavStorageAdapter` 风格一致
  - 更容易复用当前测试栈和 typed error 约束
  - transport 仍是 repo 的一等模式，不会把第三方 SDK 直接泄漏到 adapter
- Cons:
  - 需要自己处理 `ListObjectsV2` XML 解析、分页和 addressing style
  - 要新引入 `aws_signature_v4`

**Approach B: wrap `minio` package behind `S3StorageAdapter`**

- How it works:
  - 直接用 `minio` 负责对象 API
  - adapter 只做 contract 映射
- Pros:
  - 对象 API 比较全
  - 少写一部分签名与请求拼装代码
- Cons:
  - 包是 unofficial uploader 发布
  - 会绕开当前 `Dio` + interceptor + typed transport pattern
  - 测试和错误映射需要额外兜底，和现有 WebDAV 体系不对齐

**Approach C: handwrite SigV4 + raw `Dio`**

- How it works:
  - 自己实现 canonical request、string to sign、header 签名
- Pros:
  - 依赖最少
- Cons:
  - 最容易把签名细节、日期头、payload hash 做坏
  - 超出 WP4 应有边界，维护成本高

## Recommendation

推荐 **Approach A**。

这不是直接照抄 AWS 官方“优先 SDK”的建议，而是结合当前仓库约束做的推导：  
仓库已经稳定使用 `Dio`、typed exception、feature-local provider、mock transport 测试；因此 WP4 最稳的做法不是塞一个完整第三方 S3 SDK，而是保留现有 transport / adapter 分层，只把 **SigV4 签名** 作为可替换能力引入。

## Files To Modify

- `lib/shared/network/s3_api_client.dart`
  - 新增 S3 transport client，负责 SigV4、list/get/put/delete、错误映射
- `lib/features/sync/data/s3_storage_adapter.dart`
  - 实现 `SyncStorageAdapter`
  - 负责 bucket/prefix/object key 到统一 sync key 的转换
- `lib/features/sync/data/providers.dart`
  - 暴露 S3 client / adapter provider
- `test/features/sync/data/s3_storage_adapter_test.dart`
  - 覆盖成功路径、分页、401/403、404、5xx、幂等 delete
- `.trellis/spec/frontend/network-guidelines.md`
  - 补 S3-compatible transport 场景
- `.trellis/spec/architecture/local-first-sync-contract.md`
  - 补 S3 adapter 配置与分页/寻址边界

## Source Links

- AWS SigV4:
  - https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html
- AWS ListObjectsV2:
  - https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html
- AWS virtual-hosted vs path-style:
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html
- `aws_signature_v4`:
  - https://pub.dev/packages/aws_signature_v4
- `minio`:
  - https://pub.dev/packages/minio
