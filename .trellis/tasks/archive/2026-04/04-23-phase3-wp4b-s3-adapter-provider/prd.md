# 阶段3-WP4B：S3 adapter and providers

## Goal

实现 `lib/features/sync/data/s3_storage_adapter.dart` 与相关 provider，对接现有 `SyncStorageAdapter`。

## Requirements

- 复用现有 `SyncStorageAdapter`
- 吞掉 bucket/prefix/object key 细节
- 处理分页后的 `listRecords()` 聚合
- 保持与 WebDAV adapter 相同的 storage-only 边界

## Acceptance Criteria

- [ ] 新增 `S3StorageAdapter`
- [ ] 在 `providers.dart` 暴露 provider
- [ ] list/read/write/delete/tombstone 接口能对齐现有 engine
- [ ] 不引入 repository / UI 耦合
