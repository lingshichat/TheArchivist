# 阶段3-WP4A：S3 transport client

## Goal

实现 `lib/shared/network/s3_api_client.dart`，封装 S3-compatible object API 请求、SigV4 签名与 typed transport error。

## Requirements

- 支持 `ListObjectsV2` / `GetObject` / `PutObject` / `DeleteObject`
- 支持 `pathStyle` 与 `virtualHostedStyle`
- 认证使用 `SigV4`
- 不泄漏原始 transport exception

## Acceptance Criteria

- [ ] 新增 `S3ApiClient`
- [ ] 能表达 endpoint/region/bucket/rootPrefix/addressingStyle
- [ ] 401/403/404/5xx/timeout 有 typed error 映射
- [ ] 为 adapter 提供稳定 raw transport contract
