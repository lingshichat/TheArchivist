# 阶段3-WP4C：S3 adapter tests

## Goal

为 S3 transport / adapter 增加 mock 测试，覆盖成功路径、分页和错误映射。

## Requirements

- 参考 WebDAV adapter 测试模式
- 覆盖 list/read/write/delete/tombstone
- 覆盖分页、401/403、404、5xx、幂等删除/覆盖

## Acceptance Criteria

- [ ] 新增 S3 adapter 测试文件
- [ ] 关键成功/失败路径都有断言
- [ ] 测试风格与现有 sync / WebDAV 测试保持一致
