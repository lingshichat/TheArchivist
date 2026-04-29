# Bangumi 全量数据接入本地 — 调研

## 当前状态

### 已同步的字段 ✅

| Bangumi 字段 | 本地落点 | 方向 | 实现 |
|-------------|---------|------|------|
| `type` (收藏类型 1-5) | `user_entries.status` | 双向 | `BangumiTypeMapper.toUnifiedStatus` / `toCollectionType` |
| `rate` (0-10) | `user_entries.score` | 双向 | push: `updateCollection(type, rate:)` / pull: `applyRemoteStatusAndScore` |
| `ep_status` (进度) | `progress_entries.currentEpisode` / `currentPage` | 双向 | push: `updateCollection(epStatus:)` / pull: `applyRemoteProgress` |
| subject.name / nameCn | `media_items.title` / `subtitle` | pull-only | `BangumiSubjectMapper.toLocalMediaDraft` |
| subject.summary | `media_items.overview` | pull-only | `BangumiSubjectMapper.toLocalMediaDraft` |
| subject.date | `media_items.releaseDate` | pull-only | `BangumiSubjectMapper.toLocalMediaDraft` |
| subject.images | `media_items.posterUrl` | pull-only | `BangumiSubjectMapper.toLocalMediaDraft` |
| subject.totalEpisodes | `media_items.totalEpisodes` | pull-only | `BangumiSubjectMapper.toLocalMediaDraft` |

### API 已返回但未同步 ❌

| Bangumi 字段 | 来源 | 当前处理 |
|-------------|------|---------|
| `comment` (收藏短评) | `BangumiCollectionDto` | API 层已解析，sync 层完全忽略 |
| `tags` (Bangumi 标签) | `BangumiCollectionDto.tags` (List\<String\>) | API 层已解析，sync 层完全忽略 |
| `isPrivate` (收藏可见性) | `BangumiCollectionDto` | API 层已解析，sync 层完全忽略 |
| `subject.rating` (社区评分) | `BangumiSubjectDto` | API 层已解析，mapper 丢弃 |
| `updatedAt` (收藏更新时间戳) | `BangumiCollectionDto` | API 层已解析，可做冲突判定但未用 |

---

## 字段分析

### 1. 收藏 comment → review（双向同步）

**Bangumi 模型：**

收藏 comment 是用户在自己的收藏条目上写的**单条文本附言**。Bangumi 的收藏模型是"一个用户对一个条目只有一条收藏记录"，不是多评论体系。

```
芙莉莲 — 你的收藏记录（就这一条）：
  type:      2 (在看)
  rate:      9
  ep_status: 12
  comment:   "前期节奏慢但后面越来越好"   ← 单条文本
  tags:      ["奇幻", "治愈"]
  private:   false  ← 整条公开
```

**可见性：** comment 默认公开（访问你 Bangumi 主页的人都能看到你的收藏列表和附言）。隐私控制是**整条收藏级别**的 — `private: true` 后整条收藏（状态、评分、comment、tags）全部对外隐藏。不存在"只把 comment 设为私密"的选项。

**查看他人数据：** API 支持 `GET /v0/users/{username}/collections` 拉取其他人的公开收藏，包括他们的 comment 和评分。

**建议映射：** `comment` ↔ `user_entries.review`（公开短评）

理由：comment 默认公开，语义匹配 review。本地 `notes` 保留为纯私人笔记（不推 Bangumi），用户写 private 笔记选 notes，写公开短评选 review。

**同步方向：** 双向
- push: 本地改 review → `updateCollection(subjectId, comment:)`
- pull: 远端 comment → `applyRemoteReview(mediaItemId, comment)`
- 冲突：local-first，`updatedAt > lastSyncedAt` 时保留本地

### 2. 章节吐槽/讨论 — 全新 feature（未接入）

**Bangumi 模型：**

除了收藏 comment 之外，Bangumi 还有一个独立的**章节讨论系统**。API 端点（来自 bangumi/server issue #18）：

| 端点 | 返回 |
|------|------|
| `/v0/subjects/{id}/episodes` | 章节列表（分页） |
| 每个 episode 有独立讨论 | 多条吐槽/回复，带时间线 |
| `/v0/subjects/{id}/characters` | 关联角色 |
| `/v0/subjects/{id}/persons` | 关联人物（声优、制作人员） |

**收藏 comment vs 章节吐槽：**

| | 收藏 comment | 章节吐槽 |
|------|---------|------|
| 数量 | 每个条目 1 条 | 每集可以发多条 |
| 别人能看 | 能（公开收藏） | 能 |
| 别人能回复 | 不能 | 能 |
| 有时序 | 无 | 有（时间线） |
| 隐私控制 | `private` 整条隐藏 | 公开发布，无隐私设置 |
| 很适合做"记录感想" | 勉强（只有一条） | ✅ 每集看完写一段 |
| API 已解析 | ✅ `BangumiCollectionDto.comment` | ❌ 完全没接 |

**建议：** 章节讨论作为独立新 feature，不在本次"数据接入"范围内。本次只做收藏级数据同步。章节吐槽需要单独的调研和设计（章节列表 UI、讨论展示、发帖/回复等）。

### 3. tags (Bangumi) ↔ 本地 tag 表

**Bangumi 行为：**
- 收藏可打标签（字符串数组）
- 标签是用户自定义的，非全局分类
- API: `POST /v0/users/-/collections/:id` 的 `tags` 参数

**本地现状：**
- `tags` 表已存在，repository 已有 `syncTagsForMedia` / `attachTag` / `detachTag`
- 但未与 Bangumi tags 双向同步

**建议：** 双向同步 Bangumi tags ↔ 本地 tag 表

**同步方向：** 双向合并
- pull: 远端 tags 写入本地 tag 表（去重、补齐），不删除用户本地额外打的 tag
- push: 本地 tag 变更 → `updateCollection(subjectId, tags:)`
- 冲突：加法合并，pull 只增加不删除

### 4. 社区评分 (subject.rating)

**Bangumi 返回：**
```dart
BangumiRatingDto {
  rank: int?       // 排名
  total: int?      // 评分人数
  score: double?   // 均分 (0.0-10.0)
  count: {         // 评分分布 {"1": 5, "2": 10, ...}
    "1": int, "2": int, ... "10": int
  }
}
```

**本地现状：** media_items 表无社区评分字段

**建议：** 新增 pull-only 字段到本地，纯展示用

**选项 A（简单）：** 只在 `media_items` 加 `communityScore` + `communityRatingCount`

**选项 B（完整）：** 新表 `community_ratings(subjectId, score, count, rank, fetchedAt)` — 保留分布数据和刷新时间

**推荐选项 A**，首版只存均分和人数，后续再扩展

**同步方向：** pull-only（用户不能修改社区评分）
- 触发时机：首次导入、手动刷新
- 更新策略：每次 pull 覆盖更新

### 5. isPrivate

**Bangumi 行为：**
- 设为 true 后整条收藏对外不可见
- API: `POST /v0/users/-/collections/:id` 的 `private` 参数

**建议：** 暂不接入。本地没有"收藏可见性"的概念，强行引入会增加 UX 复杂度。若日后需要，可 push 时传 `isPrivate`。

---

## 本地 Schema 扩展

### media_items 新增列

| 列名 | 类型 | 用途 |
|------|------|------|
| `communityScore` | RealColumn, nullable | 社区均分 (0-10) |
| `communityRatingCount` | IntColumn, nullable | 评分人数 |

### user_entries 新增方法（repository）

| 方法 | 用途 |
|------|------|
| `applyRemoteReview(mediaItemId, review)` | pull 时写入远端 comment |
| `applyRemoteTags(mediaItemId, tags)` | pull 时合并远端 tags |

### sync_service 扩展

| 参数 | 当前 | 新增 |
|------|------|------|
| `pushCollection` | status, score | + comment, tags |
| `_reconcileCollection` | status, score | + comment, tags |
| `_importMissingCollection` | metadata, status, score | + comment, tags |

---

## 实施建议

本次只做**收藏级数据同步**，拆为 3 个子任务：

1. **WP1: comment ↔ review 双向同步** — push + pull 打通收藏附言
2. **WP2: tags 双向同步** — 本地 tag 表 ↔ Bangumi tags，加法合并策略
3. **WP3: 社区评分落库** — `communityScore`/`communityRatingCount` 新增列 + pull 写入

优先级：WP3 > WP1 > WP2（先丰富展示数据，再做双向交互）

**明确不包含：** 章节吐槽/讨论系统（需要独立调研和设计：章节列表 UI、讨论展示、发帖/回复），列为后续独立任务。

## 相关 API 端点总览

| 端点 | 用途 | 当前状态 |
|------|------|---------|
| `/v0/subjects/{id}` | 条目详情（含社区评分） | ✅ 已使用 |
| `/v0/users/-/collections` | 自己收藏列表（增删改查） | ✅ push + pull 已接 |
| `/v0/users/{username}/collections` | 他人公开收藏（含评论/评分） | ✅ API 已封装，未用 |
| `/v0/subjects/{id}/episodes` | 章节列表 + 吐槽讨论 | ❌ 未接 |
| `/v0/subjects/{id}/characters` | 关联角色 | ❌ 未接 |
| `/v0/subjects/{id}/persons` | 关联人物（声优/制作） | ❌ 未接 |

---

## 代码复核补充（2026-04-26）

### 已确认的实现基础

- `BangumiApiService.updateCollection(...)` 已支持 `comment`、`tags`、`private`、`ep_status` 参数，API 层不需要大改。
- `BangumiCollectionDto` 已解析 `comment`、`tags`、`isPrivate`、`updatedAt`、`subject.rating`。
- `user_entries.review` 字段已存在，但详情页当前只展示/编辑 `notes`，没有公开短评入口。
- `TagRepository.syncTagsForMedia(...)` 当前是“目标集合覆盖式同步”，会删除本地未出现在输入里的标签；Bangumi pull 需要新增“只追加远端标签”的入口，不能复用覆盖式方法。
- `media_items` 当前没有 `communityScore` / `communityRatingCount`，需要 Drift `schemaVersion`、migration、generated code 同步。
- Bangumi pull 当前以 `updatedAt > lastSyncedAt` 判定本地脏数据；新增 `review` / `tags` 后要继续遵守 local-first，不得远端覆盖本地脏值。

### 当前分歧点

1. `review` 是否只做后端字段同步，还是同时补一个“公开短评”编辑/展示入口。
2. `tags` push 是否用本地全部 tag 覆盖 Bangumi tags；pull 是否只追加远端 tag，不删除本地 tag。
3. 社区评分是否只存 `score + total`，暂不保存 `rank` 和评分分布。

### 推荐 MVP

- WP3：先做 `subject.rating.score/total` 落库，导入和刷新时覆盖更新。
- WP1：做 `comment ↔ user_entries.review` 双向同步，同时补最小 UI，否则用户无法编辑本地 review。
- WP2：做 Bangumi tags 双向同步，但 pull 只追加不删除，push 发送本地当前标签全集。

### 决策记录

- `review` 进入本次 MVP 的最小 UI。
- `notes` 继续作为本地私有笔记，不同步到 Bangumi。
- UI 文案应区分“公开短评”和“私人笔记”，避免用户把私密内容写进会同步到 Bangumi 的字段。

### 明确延后

- `isPrivate` 不接。
- 章节讨论、角色、人物不接。
- 社区评分分布、rank、评分刷新时间不接。
- Bangumi tag 与本地 tag 的来源标记不接，先复用现有 tag 表。

---

## 实现收尾记录（2026-04-26）

### 已完成

- `comment` 已双向接入：Bangumi `comment` ↔ 本地 `user_entries.review`。
- `tags` 已双向接入：push 发送本地当前标签；pull 只追加远端标签，不删除本地标签。
- `subject.rating.score/total` 已落库到 `media_items.communityScore/communityRatingCount`。
- `subject.tags` 已解析并接入本地 tags；Quick Add 会立即追加 subject 公共标签，pull 时也会用 subject detail 兜底补齐。
- 详情页已补齐展示：
  - `PUBLIC REVIEW`
  - `PRIVATE NOTES`
  - `BANGUMI RATING`
  - quick stats 的 `BGM SCORE`
- 编辑弹窗已补 `Public review` 字段，并区分公开短评和私有笔记。
- Bangumi OAuth 已内置桌面端默认配置；裸 `flutter run -d windows` 可启用浏览器登录。
- 设备同步快照和 codec 已包含社区评分字段。

### 验证

- `dart analyze` 已通过本任务全部变更文件。
- `flutter test` 已通过本任务相关回归：
  - `test/features/add/data/bangumi_quick_add_controller_test.dart`
  - `test/features/bangumi/data/bangumi_pull_service_test.dart`
  - `test/features/bangumi/data/bangumi_sync_service_test.dart`
  - `test/features/settings/presentation/bangumi_connection_section_test.dart`
  - `test/features/sync/data/sync_engine_test.dart`
  - `test/shared/data/repository_test.dart`

### 已知外部阻塞

- `dart analyze lib test` 仍被既有 `lib/features/lists/lists/**` 重复目录的错误阻塞；该目录不属于本任务改动。

### 待人工验收

- Windows 桌面端裸 `flutter run -d windows` 后，设置页应显示 `Browser login is enabled for this desktop build.`。
- 浏览器授权后能连接 Bangumi，并触发 post-connect sync。
- Bangumi 导入条目详情页应显示 public review、Bangumi rating、远端 tags。
- 修改 public review / tags 后应同步到 Bangumi；private notes 不应同步。

---

## 补充设计：为已添加条目匹配 Bangumi 数据

### 背景

本地早期手动添加的条目可能没有 `sourceIdsJson.bangumi`，因此无法参与 Bangumi pull/push，也拿不到 Bangumi 的封面、简介、社区评分、comment、tags 等数据。

当前 Quick Add 已经能把 Bangumi subject 写入本地，并用 `sourceIdsJson` 做幂等。Add 页搜索也已经用 `bangumiLocalIndexProvider` 标记“已添加”。缺口是：详情页里没有入口把一个已有本地条目绑定到 Bangumi subject。

### 目标

- 给已存在的本地条目新增“匹配 Bangumi 数据”能力。
- 匹配成功后写入 `sourceIdsJson.bangumi`。
- 复用现有 Bangumi subject mapper，把缺失的远端元数据补进本地。
- 匹配后立即进入现有 Bangumi 同步链路。

### 推荐 UX

入口放在详情页左侧操作区：

- 条目没有 Bangumi ID：显示 `Match Bangumi Data`
- 条目已有 Bangumi ID：显示 `Refresh Bangumi Data` 或弱化为后续功能

点击后打开匹配弹窗：

1. 默认用本地标题作为搜索词。
2. 展示 Bangumi 搜索结果卡片，沿用 Add 页卡片/预览能力。
3. 用户点 `Link to this entry` 后绑定当前本地条目。
4. 成功后回到详情页，展示 Bangumi rating / tags / public review 等远端字段。

### 绑定后的数据策略

首版采用“补齐优先，不破坏本地人工数据”的策略：

| 字段 | 策略 |
|------|------|
| `sourceIdsJson.bangumi` | 必写 |
| `communityScore/communityRatingCount` | 覆盖，远端只读展示数据 |
| `posterUrl` | 本地为空才写入 |
| `overview` | 本地为空才写入 |
| `releaseDate` | 本地为空才写入 |
| `subtitle` | 本地为空才写入 |
| `totalEpisodes/totalPages` | 本地为空才写入 |
| `title` | 默认不覆盖 |
| `mediaType` | 默认不覆盖，避免用户已有分类被强改 |
| `review/comment` | 绑定后可从收藏接口拉取；若本地 review 已有，按 local-first 保留 |
| `tags` | 远端 tags 只追加，不删除本地 tag |

### 技术设计

新增一个 feature controller：

- `BangumiMatchController.matchExistingEntry(mediaItemId, subject)`

职责：

1. 校验当前本地条目存在。
2. 检查 subject 是否已绑定到其他本地条目。
3. 写入 `sourceIdsJson.bangumi`。
4. 调用 subject mapper 生成远端元数据草稿。
5. 仅补齐本地空字段，并覆盖社区评分。
6. 如果用户已登录 Bangumi，尝试拉取该 subject 的收藏记录：
   - 已收藏：合并 comment / tags / status / score / progress。
   - 未收藏：只保留 subject 元数据，不自动创建远端收藏。
7. 追加 activity log：`matchedBangumi` 或复用 `added` payload 中的 source 记录。

仓储需要补一个窄方法：

- `MediaRepository.attachSourceAndFillMissingMetadata(...)`

这个方法只负责本地媒体字段，不直接调用 Bangumi API。

UI 复用：

- 搜索请求复用 `BangumiSearchController`。
- 搜索结果卡片复用 `BangumiSearchResultCard`。
- subject 预览复用 `BangumiSubjectPreviewDialog` 的展示结构，但按钮文案改为 `Link to this entry`。

### 冲突与防误绑

- 如果目标 Bangumi subject 已经绑定到另一个本地条目，阻止绑定，并提示打开已有条目。
- 如果当前条目已经有 Bangumi ID，首版不允许直接改绑；需要先做“解除绑定/重新绑定”的独立设计。
- 匹配弹窗展示本地标题和 Bangumi 标题，避免用户误点。
- 搜索结果只展示可映射的 Bangumi 类型：book / animation / game / live action，继续排除 music。

### MVP 验收

- [ ] 手动添加的本地条目可以从详情页搜索并绑定 Bangumi subject。
- [ ] 绑定后 `sourceIdsJson` 包含 Bangumi subject id。
- [ ] 绑定后详情页能展示 Bangumi 社区评分。
- [ ] 本地已有标题、类型、review、notes 不被远端覆盖。
- [ ] 远端 tags 只追加到本地。
- [ ] 已被其他本地条目绑定的 subject 不会重复绑定。
- [ ] 有 widget/controller/repository 测试覆盖绑定、重复绑定、防覆盖本地字段。

### 非本次范围

- 自动批量匹配整个库。
- 模糊匹配置信度模型。
- 改绑/解绑 Bangumi subject。
- 用 Bangumi 覆盖本地标题和类型。
