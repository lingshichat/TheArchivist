# 阶段2-WP1：网络基础设施与 Bangumi API 客户端

## 目标

从零搭建 Bangumi API 对接所需的网络基础设施，供 WP2（搜索 UI）和 WP3（绑定同步）直接复用。

## 前置 auto-context（已确认）

* **依赖现状**：pubspec 里只有 riverpod 2.6 / go_router 16 / drift 2.22 / drift_flutter / uuid / path_provider，**无 HTTP 客户端**，需新增 `dio`
* **build_runner 已接入**（drift 在用 2.4.x），如果选择 code-gen 路线无需新增构建工具依赖
* **Provider 风格**：手写 `final xxxProvider = Provider<T>((ref) { ... });`，未启用 `riverpod_generator`；本 WP 的 provider 按相同风格写
* **域枚举**：`MediaType { movie, tv, book, game }`、`UnifiedStatus { wishlist, inProgress, done, onHold, dropped }` 已在 `lib/shared/data/tables/enums.dart`，`BangumiTypeMapper` 直接 import 引用，不重新定义
* **`media_items` schema 已就位**：`posterUrl`, `sourceIdsJson`, `overview`, `runtimeMinutes`, `totalEpisodes`, `totalPages`, `estimatedPlayHours` 都在（阶段1-WP2 已建），本 WP 不改 schema

## 范围

* 添加 `dio` 依赖
* `lib/shared/network/bangumi_api_client.dart` — 封装 base URL、默认 headers、拦截器
* `BangumiApiException` — 统一错误映射（至少含 statusCode + message + 可选子类）
* `lib/features/bangumi/data/bangumi_api_service.dart` — 类型化 API 方法
* `lib/features/bangumi/data/bangumi_models.dart` — Bangumi 响应 DTO
* `lib/features/bangumi/data/bangumi_type_mapper.dart` — 类型映射
* Subject 详情的轻量缓存（300s）
* Riverpod provider 注册
* 单元测试

## API 方法清单

| 方法 | 端点 | 认证 |
|------|------|------|
| `searchSubjects(keyword, {filter, limit, offset})` | `POST /v0/search/subjects` | 可选 |
| `getSubject(id)` | `GET /v0/subjects/{id}` | 可选 |
| `getMe()` | `GET /v0/me` | 必需 |
| `updateCollection(subjectId, {type, rate, comment, private, tag})` | `POST /v0/users/-/collections/{id}` | 必需 |
| `patchCollection(subjectId, body)` | `PATCH /v0/users/-/collections/{id}` | 必需 |
| `getCollection(username, subjectId)` | `GET /v0/users/{name}/collections/{id}` | 可选 |

## 类型映射规则

SubjectType → MediaType：1→book, 2→tv, 4→game, 6→movie（totalEpisodes>1 则 tv）
CollectionType → UnifiedStatus：1→wishlist, 2→inProgress, 3→done, 4→onHold, 5→dropped

## Research Notes

### Bangumi API 已知关键约束

* **Base URL**：`https://api.bgm.tv`
* **User-Agent 必须自定义**：未设置 UA 的请求会被 **412 Precondition Failed** 拒绝；约定格式 `{appname}/{version} ({contact})`，示例 `record-anywhere/0.1.0 (https://github.com/lingshi/record-anywhere)`。在 `BangumiApiClient` 构造时写入默认 headers，读取 pubspec 版本
* **认证**：HTTP `Authorization: Bearer <access_token>`
* **Access Token 获取入口**：`https://next.bgm.tv/demo/access-token`
* **搜索分页**：`limit` + `offset`，默认 `limit: 20`，最大 `50`
* **搜索响应**：`{ total, data: [...], limit, offset }`，DTO 需要支持分页元数据
* **无官方 rate limit 文档**，但 UA 缺失/非法会 412；遵守响应里的 `Retry-After`
* **Accept**：统一 `application/json`

### 依赖方案对比（为何选 dio 不选 http）

* `package:http` 原生无拦截器，token 注入和错误映射要手写包装
* `dio` 支持 interceptor、transformer、cancelToken，社区 Flutter 项目主流选择
* → WP1 直接选 `dio`，不评估 `retrofit`（代码生成过重）、不评估 `chopper`

### 周边包的取舍

* `dio_cache_interceptor`：本 WP 只需缓存 `getSubject`（单键单 TTL），**不引入**，手写 `Map<int, _CacheEntry>` 300s TTL
* `dio_smart_retry`：本 WP 不做重试（同步失败让 WP3 轻提示即可），**不引入**
* HTTP mock：选 `http_mock_adapter`（dio 官方推荐的测试 adapter），不引入 `mockito` 生成

## Expansion Sweep

### 未来演进（1–3 月）

* Bangumi → 本地全量导入（需要 `getCollection` 遍历分页） → WP1 已包含 `getCollection`，无需预留额外接口
* 剧集进度推送 → 需要 `PUT /v0/users/-/collections/-/episodes/{id}`，**本 WP 先不加**，留到 follow-up 扩 `BangumiApiService`
* 多源搜索 → 保持 `BangumiApiService` 职责单一，不在本层做源抽象

### 相关场景

* WP3 需要 `getMe()` 验证 token → 已在方法清单
* WP2 已在库判断只用 `sourceIdsJson`，**不**需要调用 `getCollection` → `getCollection` 仅供 WP3 做可选远端比对

### 失败 / 边界

* 网络断连 → dio 抛 `DioExceptionType.connectionError`，统一映射为 `BangumiApiException.network`
* 401/403 → `BangumiApiException.unauthorized`，WP3 据此提示重新授权
* 404 → `BangumiApiException.notFound`
* 412 → `BangumiApiException.badRequest`（UA 缺失，属实现错误，应触发单元测试失败）
* 429 / 5xx → `BangumiApiException.serverError`，WP3 轻提示失败后不再重试
* 超时默认：connectTimeout 10s，receiveTimeout 15s

## 已决默认（不再回问）

| 项 | 决策 |
|----|------|
| HTTP 客户端 | `dio ^5.x` |
| 缓存实现 | 手写 `Map<int, (BangumiSubjectDto, DateTime)>`，300s TTL，key=subjectId |
| 重试策略 | 本 WP 不做，失败直接抛 |
| Token 注入 | `BangumiApiClient` 接受 `Future<String?> Function() tokenProvider`，每次请求拦截器异步读取；WP3 的 `flutter_secure_storage` 实现此 callback 并用 `bangumiAuthProvider` 触发刷新。WP1 自带一个 `static alwaysNull` 默认实现供搜索类无认证调用测试使用 |
| User-Agent | `record-anywhere/<pubspec.version> (https://github.com/lingshi/record-anywhere)`；客户端构造时从 `PackageInfo` 读版本，测试里注入固定值 |
| 错误分类 | `BangumiApiException` 抽象类 + `network` / `unauthorized` / `notFound` / `badRequest` / `serverError` / `unknown` sealed 子类（Dart 3 sealed class） |
| HTTP mock | 测试用 `http_mock_adapter`（dev_dependency） |
| 超时 | connect 10s / receive 15s |
| 默认分页 | 搜索 limit=20，offset=0 |
| DTO 序列化 | **手写** `fromJson` / `toJson`，不引入 `json_serializable` / `freezed`；DTO 放在 `bangumi_models.dart` 单文件，`const` 构造 + `final` 字段 |

## 待定（需确认）

* （无）

## 实施前 Research Pass（已补）

### Relevant Specs

* `.trellis/spec/architecture/system-boundaries.md`
  * 约束 `shared/network`、`features/bangumi/data`、provider 归属和依赖方向
* `.trellis/spec/architecture/local-first-sync-contract.md`
  * 约束 `sourceIdsJson` 映射形状和本地优先 / 远端副作用边界
* `.trellis/spec/frontend/network-guidelines.md`
  * 约束 `BangumiApiClient → BangumiApiService → providers` 分层、错误映射、缓存、测试
* `.trellis/spec/backend/error-handling.md`
  * 约束 `DioException → BangumiApiException` sealed class 映射
* `.trellis/spec/backend/quality-guidelines.md`
  * 约束 service / repository / provider 的质量检查点
* `.trellis/spec/frontend/state-management.md`
  * 约束 integration provider 放在 `features/bangumi/data/providers.dart`

### Code Patterns Found

* `lib/shared/data/providers.dart`
  * 当前 Riverpod provider 使用手写 `Provider<T>((ref) { ... })`，本 WP 沿用
* `lib/features/add/data/add_entry_controller.dart`
  * feature data 层使用构造函数注入依赖，不启用 code-gen provider
* `test/shared/data/repository_test.dart`
  * 测试使用显式构造依赖、`flutter_test`、必要时 `NativeDatabase.memory()`
* `lib/shared/data/app_database.dart`
  * `MediaType`、`UnifiedStatus` 从 `app_database.dart` 导出，可供 mapper 直接复用

### Files to Modify

* `pubspec.yaml`
  * 新增 `dio`、`package_info_plus`；dev dependency 新增 `http_mock_adapter`
* `lib/shared/network/bangumi_api_client.dart`
  * 新建 Bangumi transport client，封装 base URL、headers、token interceptor、错误映射
* `lib/features/bangumi/data/bangumi_models.dart`
  * 新建手写 DTO，覆盖搜索结果、subject、user、collection 相关响应
* `lib/features/bangumi/data/bangumi_api_service.dart`
  * 新建 typed API service，含 6 个 PRD 指定方法和 `getSubject` 300s TTL 缓存
* `lib/features/bangumi/data/bangumi_type_mapper.dart`
  * 新建 SubjectType / CollectionType 与本地域枚举的双向映射
* `lib/features/bangumi/data/providers.dart`
  * 新建 Bangumi integration provider，保持模块内聚
* `test/features/bangumi/data/*`
  * 新增 API client/service/mapper/cache/error mapping 测试

### Context Files

已初始化：

* `implement.jsonl`
* `check.jsonl`
* `debug.jsonl`

已补充 current PRD、父阶段 PRD、architecture/backend/frontend specs、provider 模式、测试模式等上下文。

## 验收标准

* [ ] `dio` 已添加到 pubspec.yaml
* [ ] `BangumiApiClient` 可配置 base URL 和 Bearer token（通过 `tokenProvider` 注入）
* [ ] 默认 `User-Agent` 写入所有请求，缺失时单元测试 fail
* [ ] HTTP 异常统一映射到 `BangumiApiException` 子类，覆盖 network / unauthorized / notFound / serverError
* [ ] `BangumiApiService` 提供上述 6 个类型化方法
* [ ] `searchSubjects` 返回值包含 `{ total, data, limit, offset }`
* [ ] `getSubject` 带 300s 轻量缓存，同一 id 在 TTL 内只发一次 HTTP 请求
* [ ] `BangumiTypeMapper` 双向映射正确（SubjectType ↔ MediaType、CollectionType ↔ UnifiedStatus）
* [ ] provider 注册到新 `lib/features/bangumi/data/providers.dart`（保持 bangumi 模块内聚），并由 `lib/shared/data/providers.dart` 间接 re-export 或各自单独 import
* [ ] API 客户端、错误映射、类型映射、300s 缓存有单元测试（`http_mock_adapter` 驱动）

## 依赖

* 无外部任务依赖（阶段1 已完成）

## 为后续 WP 留的接口

* `BangumiApiService.searchSubjects(keyword, filter, limit, offset)` 供 WP2 使用
* `BangumiApiService.getSubject(id)` 供 WP2 / WP3 使用
* `BangumiApiService.updateCollection(...)` / `getMe()` 供 WP3 使用
* `BangumiApiClient(tokenProvider:)` 让 WP3 注入 secure_storage 读取逻辑
* `BangumiTypeMapper` 供 WP2（映射搜索结果到本地 MediaItem）/ WP3（状态推送）使用
