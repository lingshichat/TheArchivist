# 阶段2-WP3：Bangumi 绑定与双向同步（状态 / 评分）

## 目标

把当前 WP3 从“绑定 + 本地 -> Bangumi 推送”扩成可落地的首版双向同步：

* 用户能在设置页绑定 / 断开 Bangumi
* Access Token 走安全存储，应用重启后可自动恢复
* 连接成功后、启动恢复后、用户手动触发时，能把 Bangumi 已有收藏拉回本地
* Quick Add 和详情页状态 / 评分修改后，继续按本地优先原则推送到 Bangumi
* 双向同步首批字段只覆盖：`status`、`score`
* 同步结果只做轻反馈或摘要反馈，不阻断主流程、不把设置页做成运维后台

> 本次脑暴收敛：先把“已有 Bangumi 收藏能进本地库”这条主诉求解决，再保留后续把进度同步补齐的扩展位。

## 前置依赖

* WP1 已在仓库内落地：
  * `lib/shared/network/bangumi_api_client.dart`
  * `lib/features/bangumi/data/bangumi_api_service.dart`
  * `lib/features/bangumi/data/bangumi_models.dart`
  * `lib/features/bangumi/data/bangumi_type_mapper.dart`
* WP2 已在仓库内落地：
  * `/add` 搜索结果与 Quick Add UI
  * `BangumiQuickAddController` 的本地写入链路
  * Quick Add 末尾已预留 `bangumiSyncService.pushCollection(...)` hook
* 详情页本地保存链路已存在：
  * `lib/features/detail/data/detail_actions_controller.dart`
* 当前桌面 OAuth 登录已走通：
  * 浏览器登录 -> 本地回调 -> access token 验证 -> 会话建立

## 已知事实（repo 调研）

### 当前已经有的能力

* `BangumiApiService` 已实现：
  * `getMe`
  * `updateCollection`
  * `patchCollection`
  * `getCollection`
* `BangumiTypeMapper` 已有 `UnifiedStatus <-> CollectionType` 映射
* `BangumiQuickAddController` 已严格按“先本地写入，再调同步 hook”工作
* `showLocalFeedback(...)` 已是统一轻反馈入口
* `sourceIdsJson` 已稳定使用 `{"bangumi": "<subject_id>"}` 结构
* `MediaRepository.findBySourceId(...)` 已能按 Bangumi ID 查本地条目
* 本地表结构已有 `updatedAt` / `lastSyncedAt` / `syncVersion` 字段，可承接最小同步判定
* 当前设置页 Bangumi 连接区块和 OAuth 登录入口已存在

### 当前缺的能力

* `BangumiApiService` 还没有“按用户分页拉收藏列表”的方法
* `bangumi_sync_service.dart` 只有本地 -> Bangumi 推送，没有 Bangumi -> 本地 回拉
* 当前没有“首次导入 / 启动自动回拉 / 手动同步”入口与状态模型
* 当前没有“导入已有收藏时的创建 / 合并 / 冲突处理”服务
* `lastSyncedAt` 目前没有被 Bangumi 同步路径实际使用
* 当前反馈模型偏单条 push 结果，不适合批量 pull 的摘要回报
* 还没有覆盖双向同步的测试

### 当前约束

* 项目仍然是 local-first，本地库是运行时真相
* 远端 Bangumi 是集成边界，不是主状态拥有者
* phase 父任务 PRD 已对齐到“状态 / 评分”的双向同步边界
* 当前代码库还没有独立 sync queue、冲突中心、失败重试台

## 脑暴收敛

### 这次用户真正要解决的问题

不是“技术上把 push 改成 pull + push”本身，核心是：

* 用户已经在 Bangumi 有多年收藏
* 绑定账号后，本地应用不该还是空库
* 至少要把 Bangumi 上已有的状态 / 评分带回来

### 可行方案

#### 方案 A：首次导入 + 启动自动回拉 + 本地继续推送（推荐）

怎么做：

* 绑定成功后立刻拉一次 Bangumi 收藏列表导入本地
* 应用启动恢复会话后后台再拉一次，保持本地逐步贴近远端
* 保留 Quick Add / 详情页的本地 -> 远端 push
* 字段只先覆盖 `status` / `score`
* 遇到本地脏数据时，按 local-first 保留本地，不直接被远端覆盖

优点：

* 真正解决“已有 Bangumi 数据进不来”的主问题
* 与当前 WP3 的 auth / sync 边界一致，仍由设置页和 bangumi 模块承接
* 不需要先等 Phase 3 的跨端同步引擎

代价：

* 要补分页拉取、批量导入、摘要反馈、最小冲突策略
* 需要把当前单向同步 PRD 改成双向版本

#### 方案 B：只做“首次手动导入”，不做启动自动回拉

怎么做：

* 绑定后让用户手动点一次“从 Bangumi 导入”
* 后续仍只保留本地 -> Bangumi 推送

优点：

* 代码量更小
* 冲突场景更少

代价：

* 不算真正的双向同步
* 用户后续在 Bangumi 改过状态，本地不会自动贴近

#### 方案 C：完整双向队列 + 冲突中心 + 失败重试

怎么做：

* pull / push 都进入统一同步引擎
* 有待同步项、冲突副本、重试入口、历史记录

优点：

* 形态完整

代价：

* 明显超出当前 WP3，且会提前侵入阶段4 / phase3 的职责

### 本次推荐结论

当前 WP3 收敛为 **方案 A**：

* 做双向同步
* 但只覆盖 `status` / `score`
* pull 触发点先做：连接成功、启动恢复、手动同步
* 不引入独立 sync queue / 冲突中心 / 远端删除联动
* 进度双向同步继续留后续 Bangumi follow-up

## 需求

### R1 账号绑定与安全存储

* 继续使用 `flutter_secure_storage`
* 保留专用 token 存储抽象，生产实现走 secure storage，测试可注入 fake
* `bangumiAuthProvider` 继续对外暴露 `AsyncValue<BangumiAuth?>`
* 绑定流程：
  1. 用户输入 token 或通过浏览器 OAuth 拿到 access token
  2. 先用候选 token 调 `GET /v0/me`
  3. 验证成功后才写入 secure storage
  4. provider 刷新为已连接状态
* 应用启动时若 storage 中有 token，需要自动校验并恢复连接
* 启动时若 token 已失效，需要清掉 storage 并回到未连接状态
* UI 层不直接读取或持有原始 token；token 只通过存储抽象供 `BangumiApiClient` 回调读取

### R2 设置页 Bangumi 连接区块升级

区块继续放在设置页右侧信息区，延续现有 Stitch 风格。

未连接态：

* 展示说明文案
* 保留浏览器 OAuth 登录按钮
* 保留 Access Token 输入框
* 保留“验证并连接”按钮
* 验证失败时展示轻量错误文案，不弹阻断式对话框

已连接态：

* 展示头像、用户名 / 昵称
* 展示当前连接状态
* 展示最近一次同步摘要：
  * 最近同步时间
  * 最近同步结果
  * 导入 / 更新 / 跳过数量摘要
* 增加“Sync now”按钮
* 保留“断开连接”按钮

加载态：

* 启动恢复、验证中、初次导入中、手动同步中、断开中都要有明确 loading 状态
* 按钮禁用，避免重复提交
* 自动同步时不弹一串 toast，只展示区块内状态或最终摘要

### R3 Token 与网络层桥接

* `bangumiTokenProvider` 继续通过 token 存储抽象读取 token
* `BangumiApiClient` 继续保持“只认 callback，不缓存 token”
* `BangumiAuth` 只暴露 UI 需要的账号摘要，不把 token 暴露给页面
* 新增 pull 所需的用户名来源：
  * 直接复用 `BangumiAuth.username`
  * 不让服务层自己猜用户名

### R4 Bangumi 收藏列表拉取能力

需要在 `BangumiApiService` 上补齐“按用户分页拉收藏列表”的能力。

最小接口目标：

* 新增 `listCollections(...)` 或等价命名方法
* 支持：
  * `username`
  * `limit`
  * `offset`
  * 过滤媒介类型（至少排除 music=3）
* 返回类型化 DTO 列表，而不是 UI 直接吃原始 JSON
* 当前首版只关心 subject type：`1 / 2 / 4 / 6`
* 当列表项未内嵌完整 `subject` 时，允许 fallback 调 `getSubject(id)` 补全元数据

### R5 Bangumi -> 本地 的导入与合并

新增专门的 pull / import 服务，例如：

* `BangumiPullService`
* 或 `BangumiSyncCoordinator`（推荐由它统一编排 pull + merge + local-win 处理）

服务职责：

* 拉取当前用户的 Bangumi 收藏列表
* 分页遍历所有结果
* 只处理支持的 subject type
* 只导入当前 WP3 覆盖的字段：
  * `status`
  * `score`
* 用 `sourceIdsJson.bangumi` 与本地条目对齐
* 本地不存在时创建：
  * `MediaItem`
  * 默认 `UserEntry`
  * 然后写入远端状态 / 评分
* 本地已存在时按冲突策略合并

#### 创建本地条目时需要写入的字段

至少包括：

* `title`
* `subtitle`
* `posterUrl`
* `releaseDate`
* `overview`
* `sourceIdsJson`
* `totalEpisodes` / `runtimeMinutes` / `totalPages` / `estimatedPlayHours`（能映射则补）
* `UserEntry.status`
* `UserEntry.score`

#### 首版导入不做的事

* 不导入笔记、标签、自定义列表、favorite
* 不导入剧集 / 页数 / 时长进度
* 不按 Bangumi 删除或取消收藏去删除本地条目
* 不把 Bangumi 当作唯一主库重建整个本地数据库

### R6 双向同步触发点

#### Pull 触发点

* 首次连接成功后自动拉一次
* 应用启动恢复有效会话后后台拉一次
* 用户点击“Sync now”时手动拉一次

#### Push 触发点

Quick Add：

* 继续复用 `BangumiQuickAddController` 现有 hook
* 本地写入成功后推送远端状态

详情页：

* `applyQuickStatus(...)` 状态变化后触发 push
* `saveChanges(...)` 中：
  * 状态变化时 push `status`
  * 评分变化时 push `score`
  * 进度、笔记、标签、书架变更不触发 Bangumi push

### R7 冲突策略（本次最关键合同）

本次双向同步仍然遵守 local-first。

#### 判定规则

对已绑定 Bangumi 映射的本地条目：

* 若本地没有对应条目：远端创建本地
* 若本地有条目且本地 `UserEntry` 没有脏改动：允许远端覆盖 `status` / `score`
* 若本地有条目且存在脏改动：本地优先，远端 pull 不覆盖本地

#### 本地脏改动的最小判定

首版用以下信号即可：

* `updatedAt > lastSyncedAt`
* 或 `lastSyncedAt == null` 且本地条目已有明确状态 / 评分，不视为“空白可回填”

#### 本地优先后的处理

当 pull 发现“本地脏改动优先”时：

* 不覆盖本地 `status` / `score`
* 该条目标记为 `localWins`
* 当前轮同步结束后，可选静默回推本地当前状态到 Bangumi（推荐）
* 即使不立即回推，也不能弹阻断式冲突对话框

> 脑暴建议：实现时优先做“收集 localWins 并静默回推”，这样既守住 local-first，又能让远端最终收敛到本地。

#### 明确不做的冲突行为

* 不弹出复杂冲突解决器
* 不展示逐条 diff
* 不自动删除本地条目来迎合远端
* 不因为远端状态缺失就把本地状态清空

### R8 同步反馈与摘要状态

当前 push 成功 / 失败轻反馈机制保留，但 pull 不能复用逐条 toast。

需要新增或扩展同步状态模型，至少覆盖：

* 当前是否在同步
* 当前同步原因：
  * `startupRestore`
  * `postConnect`
  * `manual`
* 最近同步完成时间
* 最近同步结果摘要：
  * `importedCount`
  * `updatedCount`
  * `skippedCount`
  * `localWinsCount`
  * `failedCount`

反馈策略：

* 启动恢复 pull：默认静默，仅更新设置页状态
* 连接后首次 pull：可展示一句摘要，如 `Imported 23 items from Bangumi.`
* 手动同步：展示单条摘要反馈，不逐条刷屏
* 用户主动本地改状态 / 评分后的 push：继续使用单条轻反馈
* 服务层不依赖 `BuildContext`

### R9 `lastSyncedAt` / 同步标记的最小落地

为了让 pull / push 不互相打架，需要开始真正使用本地同步标记。

首版要求：

* pull 成功应用到本地后，相关本地记录要更新 `lastSyncedAt`
* push 成功后，相关本地记录也要更新 `lastSyncedAt`
* 不要求这次把全部 repository 的 `syncVersion` 规则重新做完
* 只要能支撑 WP3 的“脏改动判定”即可

### R10 测试覆盖

至少补以下测试：

* 绑定状态 provider / controller 测试
* token 存储抽象测试或 fake 验证
* `BangumiSyncService` push 测试
* pull / import 服务测试
* 冲突策略测试（本地优先 / 本地空白回填 / localWins）
* `DetailActionsController` 同步 hook 测试
* 设置页连接区块 widget 测试

## 验收标准

### 功能验收

* [ ] 设置页能输入 token 并调用 `GET /v0/me` 验证
* [ ] 验证成功后展示 Bangumi 用户信息
* [ ] token 只在验证成功后落入 secure storage
* [ ] 应用重启后能自动恢复有效绑定
* [ ] 启动时遇到失效 token 会自动清理并恢复未连接态
* [ ] 用户能断开连接并清除本地 token
* [ ] 连接成功后会自动从 Bangumi 拉取已有收藏到本地
* [ ] 启动恢复有效会话后会后台拉取一次 Bangumi 收藏
* [ ] 设置页已连接态可手动触发 `Sync now`
* [ ] Bangumi 远端已有但本地不存在的条目，会被导入为本地条目
* [ ] 已有本地 Bangumi 映射的条目不会重复创建副本
* [ ] 本地无脏改动时，pull 可回填 / 更新本地 `status` / `score`
* [ ] 本地有脏改动时，pull 不会覆盖本地 `status` / `score`
* [ ] Quick Add 在已绑定且有 Bangumi 映射时自动推送状态
* [ ] 详情页修改状态后自动推送收藏状态
* [ ] 详情页修改评分后自动推送评分
* [ ] 未绑定时 pull / push 都静默跳过，不影响本地主流程
* [ ] 同步失败时本地写入结果不变
* [ ] pull / push 的反馈都是轻量的，不阻断主流程

### 数据验收

* [ ] 远端收藏导入后，`sourceIdsJson` 仍使用 `{"bangumi": "<subject_id>"}`.
* [ ] 导入新条目时，基础元数据（标题、封面、年份、简介等）能够落入本地库
* [ ] 双向同步首批字段只覆盖 `status` / `score`
* [ ] `lastSyncedAt` 会在 pull / push 成功后更新

### 质量验收

* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过
* [ ] 不在 `presentation/` 层引入 `dio`
* [ ] 不在服务 / controller 中直接使用 `BuildContext`
* [ ] 不在代码里打印 token、Authorization header 或原始响应体
* [ ] 不新增与 Phase 3 / Phase 4 重复的“同步队列 / 冲突中心 / 运维后台”雏形

## Definition of Done

* 绑定、断开、启动恢复、首次导入、手动同步、Quick Add push、详情页 push 都已走通
* 当前任务的双向同步边界清楚收敛在“状态 / 评分”，不偷偷把进度同步一并塞进来
* 任务内新增的 provider / service / widget 都有最小必要测试
* 当前子任务的实现边界仍留在 WP3，不把跨设备同步和备份导入导出职责偷迁进来
* 如果确认按本 PRD 实现，要同步回父任务 PRD：
  * `.trellis/tasks/04-19-phase2-bangumi-flow/prd.md`
* 如果落地过程中形成了可复用契约，要同步回 `.trellis/spec/`

## 技术方案

### 总链路

```text
SettingsPage
  -> bangumiAuthProvider / controller
  -> Bangumi token store
  -> BangumiApiService.getMe()
  -> BangumiAuth
  -> postConnect pull

App startup
  -> bangumiAuthProvider.build()
  -> restore token
  -> validate session
  -> background pull

BangumiApiClient
  -> bangumiTokenProvider
  -> token store.read()

BangumiPullService / Coordinator
  -> BangumiApiService.listCollections(...)
  -> fallback getSubject(...)
  -> MediaRepository.findBySourceId(...)
  -> create / merge local item + user entry
  -> mark lastSyncedAt
  -> publish summary state

BangumiQuickAddController / DetailActionsController
  -> BangumiSyncService.pushCollection(...)
  -> sourceIdsJson 取 bangumi subject id
  -> BangumiApiService.updateCollection / patchCollection
  -> mark lastSyncedAt
  -> sync feedback provider
  -> 根级 listener 调 showLocalFeedback(...)
```

### 方案拆解

#### 1. 认证状态

继续用 `AsyncNotifierProvider<BangumiAuthController, BangumiAuth?>`：

* `build()`：启动时读取 secure storage，并校验已有 token
* `connect(token)`：校验候选 token，成功后写 storage 并更新 state
* `disconnect()`：删 storage，回到 `null`
* `connect(...)` 和 `build()` 成功后，触发一次后台 pull

#### 2. token 存储抽象

继续单独抽象成 `BangumiTokenStore`：

* 生产实现：`flutter_secure_storage`
* 测试实现：内存 fake

这样 `bangumiTokenProvider`、`bangumiAuthController`、pull / push 服务都能复用同一套契约。

#### 3. pull / merge 服务

推荐新增独立服务，而不是把所有逻辑塞回 `BangumiSyncService.pushCollection(...)`。

推荐职责拆分：

* `BangumiSyncService`
  * 继续负责本地 -> Bangumi push
* `BangumiPullService`
  * 负责 Bangumi -> 本地 拉取与合并
* `BangumiSyncStatusController`
  * 负责同步状态与摘要

这样 Quick Add / Detail 的调用面不被 pull 逻辑污染。

#### 4. 创建与合并策略

推荐以 `sourceIdsJson.bangumi` 为唯一匹配键：

* 未命中：创建本地条目
* 命中且本地 clean：更新本地 `status` / `score`
* 命中且本地 dirty：保留本地，记为 `localWins`

#### 5. 反馈策略

推荐把“单条 push 反馈”和“批量 pull 摘要”拆开：

* push：继续用现有 `bangumiSyncFeedbackProvider`
* pull：新增状态 / 摘要 provider，在设置页区块展示，并在手动同步后输出一条 summary feedback

#### 6. 最小同步标记

推荐先围绕 `UserEntry.updatedAt / lastSyncedAt` 做冲突判断：

* 不等 Phase 3 才开始用 `lastSyncedAt`
* 也不在本次把全库 syncVersion 体系一起做大
* 先让 WP3 的 status / score 双向同步有稳定判定基础

## Decision (ADR-lite)

### D1 当前 WP3 的“双向同步”只收敛到状态 / 评分

**Context**：长期产品方向是 Bangumi 双向同步，但当前 phase 父任务和 WP3 现状都把进度推迟了；一次把状态、评分、进度、冲突 UI 一起做，会把 WP3 撑爆。

**Decision**：当前 WP3 把双向同步落在 `status` / `score`，并把“已有 Bangumi 收藏导入本地”纳入本任务；进度双向同步仍留后续 Bangumi follow-up。

**Consequences**：能先解决已有 Bangumi 用户的核心痛点；实现量仍然可控；后续扩进度时还能沿用同一套 auth / pull / push 基础设施。

### D2 pull 用独立服务，push 服务保持单责

**Context**：`BangumiSyncService` 已被 Quick Add / Detail 依赖，直接把 pull、分页导入、冲突摘要全塞进去，会让现有调用面变脏。

**Decision**：新增 pull / merge 服务与状态 controller；`BangumiSyncService` 继续只处理本地 -> Bangumi push。

**Consequences**：现有 WP2 / Detail 代码改动小；设置页与启动恢复可以独立触发 pull；更符合模块边界。

### D3 冲突默认 local-first，不做复杂冲突中心

**Context**：双向同步最容易把任务做成“队列 + 冲突台 + 可视化 diff”。当前项目还没到这个阶段。

**Decision**：pull 遇到本地脏改动时，本地优先；当前版本不做逐条冲突 UI，不做远端删除联动。

**Consequences**：风险和复杂度可控；仍然守住 local-first 主体；后续真要做冲突中心，可在 phase4 / follow-up 补。

### D4 批量 pull 只给摘要反馈，不给逐条 toast

**Context**：现有轻反馈适合单条 push，不适合首次导入几十上百条收藏。

**Decision**：连接后 pull、启动 pull、手动 pull 都走摘要状态；只有用户主动本地改状态 / 评分时，才继续保留单条 push 反馈。

**Consequences**：不会刷屏；设置页能承担“同步状态总览”的职责；用户仍知道同步是否成功。

## 不包含

* Bangumi 观看 / 阅读 / 游玩进度的 pull / push
* Bangumi 章节级 / 卷级 / 时长级同步接口接入
* 远端取消收藏 -> 本地自动删除 / 自动降级
* 笔记、标签、自定义列表、favorite、review 双向同步
* 独立 sync queue 表
* 专门的失败重试入口
* 同步失败持久化到数据库
* 复杂冲突解决器 / diff UI
* 重新设计设置页整体布局
* Phase 3 的跨设备同步策略
* Phase 4 的同步运维与备份入口

## Research Notes

### Relevant Specs

* `.trellis/spec/architecture/system-boundaries.md`
  * 限定 provider、service、UI 的依赖方向
* `.trellis/spec/architecture/local-first-sync-contract.md`
  * 规定本地写入优先、远端失败不回滚
* `.trellis/spec/architecture/task-spec-governance.md`
  * 当前 scope 扩大后，父任务 PRD 也必须同步改
* `.trellis/spec/frontend/state-management.md`
  * 约束 auth provider、sync status provider 的放置方式
* `.trellis/spec/frontend/component-guidelines.md`
  * 约束设置页连接区块与轻反馈风格
* `.trellis/spec/frontend/design-system.md`
  * 约束设置页右侧分组面板的视觉合同
* `.trellis/spec/frontend/network-guidelines.md`
  * 约束 token callback、ApiClient / ApiService 分层
* `.trellis/spec/backend/error-handling.md`
  * 约束 sync 服务只处理 typed error，不外漏原始网络异常
* `.trellis/spec/backend/logging-guidelines.md`
  * 禁止打印 token 和响应体
* `.trellis/spec/backend/quality-guidelines.md`
  * 约束多步写入仍由 controller / service 编排

### 现有代码模式

* `lib/features/add/data/bangumi_search_providers.dart`
  * 现成的 Riverpod `AsyncNotifier` / controller 模式
* `lib/features/add/data/bangumi_quick_add_controller.dart`
  * 现成的 local-first + sync hook 编排方式
* `lib/features/detail/data/detail_actions_controller.dart`
  * 已有“只在值变化时才写库”的差异写入模式
* `lib/shared/widgets/local_feedback.dart`
  * 现成轻反馈 UI
* `test/features/add/data/bangumi_quick_add_controller_test.dart`
  * 现成 fake sync service 注入模式
* `lib/shared/data/repositories/media_repository.dart`
  * 已有 `findBySourceId(...)`，可先支撑 Bangumi 去重匹配

### 预计会改到的文件

* `pubspec.yaml`
* `lib/features/bangumi/data/providers.dart`
* `lib/features/bangumi/data/bangumi_api_service.dart`
* `lib/features/bangumi/data/bangumi_models.dart`
* `lib/features/bangumi/data/bangumi_sync_service.dart`
* `lib/features/bangumi/data/` 下新增 pull / status / merge 相关文件
* `lib/features/detail/data/detail_actions_controller.dart`
* `lib/features/settings/presentation/bangumi_connection_section.dart`
* `lib/app/app.dart` 或同层新增全局 sync listener
* `test/features/bangumi/data/*`
* `test/features/settings/presentation/*`
* `test/shared/data/repository_test.dart`

### 风险与边界

* phase 父任务当前仍写“首轮只推送”，当前子任务 PRD 若确认采纳，需要先改父任务 PRD，避免治理层冲突
* `MediaRepository.findBySourceId(...)` 目前是遍历查找，首版导入量若很大会慢，但作为 WP3 MVP 仍可接受
* `lastSyncedAt` 还未真正落地，pull / push 要从当前任务开始把它用起来
* pull 导入不能刷一堆 toast，否则首次导入体验会很差
* 若实现“localWins 后静默回推”，要避免在启动恢复时制造明显 UI 噪音
* 远端删除 / 取消收藏语义没有在本任务处理，必须明确留白

## Implementation Plan

### Step 1：认证与存储收口

* 保持 `BangumiTokenStore`
* 保持 `BangumiAuth` model + `bangumiAuthProvider`
* 覆盖连接 / 断开 / 启动恢复测试
* 在 auth 恢复成功后预留 / 接入后台 pull 入口

### Step 2：补齐收藏列表 API 与 DTO

* 在 `BangumiApiService` 增加 `listCollections(...)`
* 补齐 pull 所需 DTO / 分页结构
* 覆盖分页与错误映射测试

### Step 3：落地 pull / merge 服务

* 新建 `BangumiPullService` 或 `BangumiSyncCoordinator`
* 实现远端分页拉取、本地创建、合并、冲突判定
* 落地 `lastSyncedAt` 最小更新
* 覆盖 imported / updated / skipped / localWins / failure 测试

### Step 4：设置页同步状态与手动触发

* 在已连接态展示最近同步摘要
* 增加 `Sync now` 按钮
* 接入 post-connect / startup / manual 三类同步原因
* 覆盖 widget 状态测试

### Step 5：保留 push 并完成双向收口

* 保持 Quick Add / Detail 的 push 触发点
* 检查 push 成功后是否更新同步标记
* 检查 pull 不会破坏现有 push UX
* 跑 `flutter analyze lib test` 与 `flutter test`
