# 阶段3-WP3：WebDAV 适配器 Research

## Relevant Specs

- `.trellis/spec/architecture/local-first-sync-contract.md`
  - WebDAV 只能实现 `SyncStorageAdapter`
  - 远端对象布局必须复用 `entities/...` 与 `tombstones/...`
- `.trellis/spec/architecture/system-boundaries.md`
  - transport client 放 `lib/shared/network/`
  - feature provider / adapter 放 `lib/features/sync/data/`
- `.trellis/spec/backend/directory-structure.md`
  - transport config 在 `shared/network`
  - integration-specific provider 在 feature data
- `.trellis/spec/backend/error-handling.md`
  - transport 错误必须映射成 typed error
  - auth 失败可中止，404 走 not found，网络失败走 network
- `.trellis/spec/backend/quality-guidelines.md`
  - service/client 隐藏传输细节
  - 不把 `dio` 暴露到 widget / page
- `.trellis/spec/frontend/network-guidelines.md`
  - 复用现有 `Dio` client + interceptor + sealed exception 风格

## Code Patterns Found

- `lib/shared/network/bangumi_api_client.dart`
  - 已有 `Dio` 初始化、请求头注入、`DioException -> typed exception` 映射
- `lib/features/sync/data/sync_engine.dart`
  - engine 已经稳定依赖 `SyncStorageAdapter`
- `test/features/sync/data/sync_engine_test.dart`
  - 已有 in-memory adapter，证明 contract 没问题
- `test/features/bangumi/data/bangumi_api_service_test.dart`
  - 已有 `http_mock_adapter` 的网络层单测样板

## Files To Modify

- `lib/shared/network/webdav_api_client.dart`
  - 新增 WebDAV transport client，处理 Basic Auth、PROPFIND、MKCOL、错误映射
- `lib/features/sync/data/webdav_storage_adapter.dart`
  - 实现 `SyncStorageAdapter`
  - 负责 list/read/write/delete/tombstone 与目录补齐
- `lib/features/sync/data/providers.dart`
  - 暴露 WebDAV client / adapter provider
- `lib/features/sync/data/sync_exception.dart`
  - 补 `SyncServerException`
- `test/features/sync/data/webdav_storage_adapter_test.dart`
  - 覆盖成功路径、401、404、timeout、5xx、幂等目录创建

## Notes

- 当前仓库还没有 WebDAV 配置持久化；WP3 先交付 transport + adapter，配置表单归阶段4。
- 由于本地 `rtk` 包裹下 `dart` / `flutter` 工具持续超时，校验暂时只能先收在代码级 review，待后续再补跑命令。
