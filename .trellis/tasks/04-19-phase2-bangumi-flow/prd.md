# 阶段2：Bangumi 搜索、快捷添加与同步

## 目标

打通"Bangumi 搜索 → 快捷添加 → 本地保存 → 自动同步"的核心使用体验。

## 前置依赖

阶段1（`04-19-phase1-local-core`）已完成，本轮直接复用的产物：

* `media_items` 表的 `sourceIdsJson`（默认 `'{}'`，格式 `{"bangumi": "12345"}`）
* `media_items` 表的 `posterUrl`（可空，WP4 本地条目均为 null）
* `user_entries` / `progress_entries` / `activity_logs` 的完整读写链路
* `AddEntryController` / `DetailActionsController` 的写入模式
* `LocalViewAdapters` 的占位海报策略（无 `posterUrl` 时用稳定色）
* `/add` 页面已作为本地创建入口，Phase 2 在同一路由继续增强

## 范围

* Bangumi 单源搜索（`POST /v0/search/subjects`）
* 条目元数据映射与入库
* 搜索结果卡片直接添加
* 添加前状态选择层
* Bangumi 可选绑定（设置页入口，Access Token 存储）
* 状态、评分、进度自动同步（本地 → Bangumi）
* 封面图从占位色升级为远程图片

## 不包含

* 多源聚合搜索
* WebDAV / S3-compatible 跨端同步
* 冲突副本查看界面
* Bangumi → 本地 的全量拉取导入（首轮只做推送）
* Bangumi 的剧集 / 页数 / 时长进度推送
* 私人笔记、自定义标签、自定义列表回写 Bangumi
* 音乐类条目（Bangumi SubjectType=3 不映射）

---

## 父任务共享契约

本阶段父任务是 WP1 / WP2 / WP3 的共同边界。
长期规则以这里和 `.trellis/spec/` 为准，子任务只承接自己的实现片。

规范落点：

* `.trellis/spec/architecture/system-boundaries.md`：模块边界与 provider 归属
* `.trellis/spec/architecture/local-first-sync-contract.md`：本地优先、远端副作用、同步失败策略
* `.trellis/spec/frontend/network-guidelines.md`：Bangumi API Client / Service 分层
* `.trellis/spec/backend/error-handling.md`：typed error 与 local-first 错误策略

冻结规则：

* `sourceIdsJson` 使用 `{"bangumi": "<subject_id>"}` 作为 Bangumi 映射
* 本地写入永远先于远端同步，远端失败不回滚本地
* Bangumi 绑定是增强能力，不是使用前置条件
* WP2 / WP4 只调用注入式 `BangumiSyncService`，不读取 token，不直接调用 API client
* WP3 独占 token 存储、绑定状态判断、远端同步结果反馈
* 阶段2首轮只推送 Bangumi 收藏状态和评分；剧集 / 页数 / 时长进度推送留后续 follow-up

子任务分工：

* WP1：网络基础设施、DTO、类型映射、service/provider
* WP2：搜索 UI、快捷添加、本地写入、同步 hook 调用
* WP3：账号绑定、secure storage、`BangumiSyncService` 实现、同步反馈

如果任一 WP 需要修改这些共享边界，必须先改本父任务 PRD，再改对应 spec。

---

## Requirements

### R1 Bangumi API 客户端与网络基础设施

当前代码库没有任何 HTTP 客户端依赖。本轮需要从零搭建：

* 新增 `dio` 作为 HTTP 客户端（支持拦截器、超时、错误映射）
* 创建 `lib/shared/network/` 层：
  * `bangumi_api_client.dart` — 封装 base URL（`https://api.bgm.tv`）、默认 headers、请求/响应拦截
  * 错误类型：`BangumiApiException`（含 statusCode + message）
* 创建 `lib/features/bangumi/data/`：
  * `bangumi_api_service.dart` — 类型化 API 方法
  * `bangumi_models.dart` — Bangumi 响应 DTO
  * `bangumi_type_mapper.dart` — Bangumi SubjectType ↔ MediaType、CollectionType ↔ UnifiedStatus

API 方法清单：

| 方法 | 端点 | 用途 |
|------|------|------|
| `searchSubjects` | `POST /v0/search/subjects` | 搜索条目 |
| `getSubject` | `GET /v0/subjects/{id}` | 条目详情 |
| `getMe` | `GET /v0/me` | 验证 token |
| `updateCollection` | `POST /v0/users/-/collections/{id}` | 更新收藏状态+评分 |
| `patchCollection` | `PATCH /v0/users/-/collections/{id}` | 部分更新 |
| `getCollection` | `GET /v0/users/{name}/collections/{id}` | 获取远程收藏状态 |

### R2 Bangumi 搜索 UI 叠加到 `/add` 页面

WP4 已将 `/add` 作为本地创建入口。本轮在同一路由上叠加 Bangumi 搜索能力：

页面顶部新增搜索栏：
* 输入关键词后 debounce 300ms 调用 `searchSubjects`
* 支持按媒介类型筛选（默认搜全部，Bangumi type 过滤 `type: [1, 2, 4, 6]`，排除 music=3）
* 搜索结果区展示卡片列表，每张卡片包含：封面缩略图、标题（中文+原文）、年份、媒介类型标签、简介摘要
* 已在本地库的条目展示当前状态标签（通过 `sourceIdsJson` 匹配）
* 搜索无结果时走 calm `EmptyState`
* 搜索区下方保留"手动创建"入口，点击后展开 WP4 已有的手动表单

### R3 快捷添加流程

点击搜索结果卡片后：

1. 弹出状态选择层（dialog / overlay），展示 5 个 `UnifiedStatus` 选项
2. 用户选择状态后，controller 自动完成：
   * 从 Bangumi Subject 映射并创建 `MediaItem`（填充 `title`, `subtitle`, `posterUrl`, `releaseDate`, `overview`, `sourceIdsJson`, `totalEpisodes` / `runtimeMinutes` / `totalPages` / `estimatedPlayHours`）
   * 创建默认 `UserEntry` 并写入选择的状态
   * 追加 `ActivityLog`（event: `added`）
   * 若有 Bangumi 绑定，触发收藏同步推送
3. 保存成功后：
   * 轻反馈"已加入本地"
   * 用户可继续搜索添加下一条（不强制跳详情页）
   * 或点击"查看详情"跳转 `DetailPage`

### R4 Bangumi 类型映射规则

Bangumi SubjectType → 本地 MediaType：

| SubjectType | Bangumi 标签 | 本地 MediaType | 备注 |
|-------------|-------------|---------------|------|
| 1 | 书籍 | `book` | 直接映射 |
| 2 | 动画 | `tv` | 包括动画剧场版，暂不细分 |
| 4 | 游戏 | `game` | 直接映射 |
| 6 | 三次元 | `movie` | 默认映射为 movie；若 `total_episodes > 1` 则映射为 `tv` |

Bangumi CollectionType → 本地 UnifiedStatus：

| CollectionType | Bangumi 标签 | 本地 UnifiedStatus |
|----------------|-------------|-------------------|
| 1 | 想看/想读/想玩 | `wishlist` |
| 2 | 在看/在读/在玩 | `inProgress` |
| 3 | 看过/读过/玩过 | `done` |
| 4 | 搁置 | `onHold` |
| 5 | 抛弃 | `dropped` |

评分：Bangumi 和本地均为 0-10 整数，直接映射。

### R5 Bangumi 账号绑定与认证

设置页新增"Bangumi 连接"区块：

* 用户输入 Access Token（从 `https://next.bgm.tv/demo/access-token` 获取）
* 验证：调用 `GET /v0/me` 确认 token 有效
* 展示已连接账号信息：用户名、头像
* 支持断开重连
* Token 存储：使用 `flutter_secure_storage` 加密存储
* Provider：`bangumiAuthProvider` — `AsyncValue<BangumiAuth?>`

Bangumi 绑定规则（遵守父 PRD）：
* Bangumi 不是使用本应用的前置条件
* 未绑定时搜索可用（搜索不需要认证）
* 未绑定时同步静默跳过，不打扰本地操作

### R6 自动同步引擎（本地 → Bangumi）

同步触发时机：
* 快捷添加新条目后（若已绑定）
* 详情页修改状态 / 评分后（若已绑定）

同步策略：
* 本地写入优先，同步是异步后台动作
* UI 优先反馈"已保存到本地"
* 同步成功后轻反馈"已同步到 Bangumi"
* 同步失败时：本地记录保留，只做轻提示和失败记录
* 不回滚本地数据
* 不引入独立 sync queue 表、待同步列表或专门重试队列

同步字段范围：
* 状态（`UnifiedStatus` → `CollectionType`）
* 评分（0-10 整数）
* **本阶段不同步**：剧集 / 页数 / 时长进度
* **不同步**：笔记、标签、自定义列表、review、favorite

同步前提条件：
* 条目 `sourceIdsJson` 中包含 `"bangumi"` key
* 用户已绑定 Bangumi（`bangumiAuthProvider` 有有效 token）

### R7 封面图从占位色升级为远程图片

Bangumi 搜索结果和快捷添加会带来真实封面 URL：

* `posterUrl` 写入 `media_items.posterUrl`
* 现有 `PosterViewData` 已有 `posterUrl` 字段
* 新增 `cached_network_image` 依赖
* `PosterCard` / `PosterArt`：`posterUrl` 非 null 时加载远程图片，null 时保持 WP4 占位色策略
* 图片加载失败时 fallback 到占位色，不显示 broken image

### R8 搜索与同步相关空状态

补充以下空状态：

* 搜索无结果
* 网络不可用时的搜索错误状态
* Bangumi 连接验证失败
* 同步失败待重试

---

## Acceptance Criteria

### 功能验收

* [ ] 在 `/add` 页面输入关键词后能看到 Bangumi 搜索结果
* [ ] 搜索结果卡片显示封面、标题（中/原文）、年份、媒介类型、简介
* [ ] 点击搜索结果弹出状态选择层
* [ ] 选择状态后条目写入本地库，`sourceIdsJson` 包含 Bangumi ID
* [ ] 添加后可继续搜索添加下一条
* [ ] 已在库的条目在搜索结果中显示当前状态标签
* [ ] "手动创建"入口仍可正常使用
* [ ] 设置页可输入 Bangumi Access Token 并验证
* [ ] 绑定后快捷添加和修改状态/评分自动推送到 Bangumi
* [ ] 同步失败时本地记录不受影响
* [ ] 封面图正常加载，加载失败时 fallback 到占位色

### 数据验收

* [ ] Bangumi SubjectType 正确映射到本地 MediaType
* [ ] `posterUrl` 从 Bangumi `image.common` 写入
* [ ] `sourceIdsJson` 格式为 `{"bangumi": "<subject_id>"}`
* [ ] 快捷添加的条目元数据完整（标题、副标题、年份、简介、集数等）

### 质量验收

* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过
* [ ] Bangumi API 客户端有基础单元测试
* [ ] 类型映射有单元测试
* [ ] 同步引擎有 mock 测试

---

## Implementation Plan (work packages)

### WP1：网络基础设施与 Bangumi API 客户端

* `dio` 依赖
* `lib/shared/network/bangumi_api_client.dart`
* `lib/features/bangumi/data/bangumi_api_service.dart`
* `lib/features/bangumi/data/bangumi_models.dart`
* `lib/features/bangumi/data/bangumi_type_mapper.dart`
* Riverpod provider 注册
* API 客户端单元测试 + 类型映射测试

### WP2：搜索 UI 与快捷添加

* `/add` 页面顶部搜索栏 + 结果列表
* 搜索 debounce + 状态管理
* 搜索结果卡片组件
* 状态选择层 dialog
* `BangumiQuickAddController`
* "已在库"指示器
* 封面图加载（`cached_network_image`）
* 搜索空状态和错误状态

### WP3：Bangumi 绑定与自动同步

* `flutter_secure_storage` 依赖
* Token 存储与验证
* `bangumiAuthProvider`
* 设置页 Bangumi 连接区块
* 同步引擎：监听本地变更 → 推送到 Bangumi
* 同步状态轻反馈
* 同步失败标记与静默处理

---

## Decision (ADR-lite)

### D1 搜索叠加到 `/add` 路由，不新增独立搜索页

**Context**：WP4 已把 `/add` 作为本地创建入口。父 PRD 和阶段1 PRD 都预留了"Phase 2 在同一路由继续增强"。

**Decision**：在 `/add` 页面上方叠加搜索区，搜索结果在上，手动创建表单在下。

**Consequences**：首页/库页空状态的"添加"动作不需改路由；用户心智模型不变。

### D2 首轮同步只做推送，不做全量拉取

**Context**：Bangumi 的 `GET /v0/users/{name}/collections` 可以拉取用户完整收藏列表，但全量导入涉及去重、冲突、进度映射等复杂逻辑。

**Decision**：WP4 只做本地 → Bangumi 的推送同步。Bangumi → 本地的全量导入留给后续 `followup` 任务。

**Consequences**：本轮同步链路更短、更稳定；已有 Bangumi 数据的用户需等后续版本导入。

### D3 封面图用 `cached_network_image`，不额外设计图片管理

**Context**：WP4 本地条目没有封面。Bangumi 带来封面后需要加载远程图片。

**Decision**：引入 `cached_network_image`，在 `PosterCard` / `PosterArt` 中判断 `posterUrl` 是否存在。null 则走占位色策略。

**Consequences**：最小改动实现封面加载；图片缓存由库管理；Phase 3 不需要重新设计图片层。

### D4 同步失败只做轻提示，不引入复杂重试队列

**Context**：父 PRD 的长期方向包含待同步状态和重试入口，但这类同步运维能力更适合放到阶段4统一收口。

**Decision**：首轮只做轻量处理：同步失败时保留本地写入，只给轻提示和失败记录，不引入独立 sync queue 表、待同步列表或专门重试队列。

**Consequences**：实现简单；失败运维能力会弱一些，留给 Phase 4 / follow-up 统一补齐。

---

## Technical Notes

### Bangumi API 概要

* Base URL：`https://api.bgm.tv`
* 认证：HTTP Bearer Token（Access Token）
* 搜索：`POST /v0/search/subjects`，body 含 `keyword` + `filter`
* 详情：`GET /v0/subjects/{id}`，返回完整 Subject（含 `name`, `name_cn`, `summary`, `date`, `image`, `rating`, `eps`）
* 收藏更新：`POST /v0/users/-/collections/{id}`，需 Bearer token
* 用户信息：`GET /v0/me`，验证 token
* 缓存：Subject 详情缓存 300s
* 无明确 rate limit 文档，需尊重缓存头

### Bangumi Subject 关键字段映射

| Bangumi 字段 | 本地字段 |
|-------------|---------|
| `id` | `sourceIdsJson: {"bangumi": "<id>"}` |
| `name` | `title` |
| `name_cn` | `subtitle` |
| `summary` | `overview` |
| `date` | `releaseDate` |
| `image.common` | `posterUrl` |
| `type` (SubjectType) | `mediaType`（经 mapper 转换）|
| `eps` / `total_episodes` | `totalEpisodes` |

### 当前 `media_items` schema 已就绪

```text
posterUrl        TEXT NULL       -- Bangumi image.common
sourceIdsJson    TEXT DEFAULT '{}'  -- {"bangumi": "12345"}
overview         TEXT NULL       -- Bangumi summary
runtimeMinutes   INT NULL        -- movie 时长
totalEpisodes    INT NULL        -- TV 集数
totalPages       INT NULL        -- 书籍页数
estimatedPlayHours REAL NULL     -- 游戏时长
```

所有 Bangumi 需要的字段都已在 WP2 阶段建好，本轮不需要改 schema。

### 现有占位海报策略

`LocalViewAdapters._paletteFor()` 按 `mediaType + title` hash 生成稳定占位色。当 `posterUrl` 非 null 时，应优先加载远程图片；加载失败或 `posterUrl` 为 null 时 fallback 到占位色。这样 WP4 的本地条目和 Phase 2 的 Bangumi 条目可以共存。
