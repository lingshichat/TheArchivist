# 阶段1-WP4：本地记录动作与空状态

## Goal

把 WP1、WP2、WP3 串成一个真正可用的本地闭环。

当前基础已经具备：

* **WP1** 已完成桌面壳、主题令牌、共享空状态组件和设计契约
* **WP2** 已完成 Drift 表结构、仓储层和基础仓储测试
* **WP3** 已完成 Windows 首页 / 库页 / 详情页骨架，以及 view data provider 边界

本任务负责把这些骨架接到真实本地数据上，并补齐阶段1缺的最后一段链路：

* 首次进入应用时能从空状态走到本地创建
* 首页、库页、详情页不再吃 `DemoData`
* 详情页可直接改状态、评分、进度、笔记
* 标签、自定义列表也能完成最小挂接和回显
* 修改后立即落本地，并能在首页 / 库页 / 详情页联动回显
* 生命周期日志、空状态、删除收口都能成立

这轮仍然坚持：

* 不依赖 Bangumi
* 不启用同步
* 不把 Phase 2 / Phase 3 的能力提前硬塞进来

## Requirements

### R1 读链路切到真实本地数据

* `lib/features/home/data/home_view_data.dart`
* `lib/features/library/data/library_view_data.dart`
* `lib/features/detail/data/detail_view_data.dart`

以上 3 个 feature data 层不再返回 `Demo*ViewDataSource` 的静态数据，改为基于 Drift / repository 的本地 provider。

保留 WP3 已经建立的 **view data 适配边界**：

* 页面层继续消费 `HomeViewData` / `LibraryHeaderViewData` / `DetailViewData`
* `shared/widgets/` 继续只接 `PosterViewData`、`CategoryViewData` 这类轻量 UI 模型
* 不让页面直接拼 DAO / SQL 细节

### R2 首页 / 库页 / 详情页联动真实本地库

接入后要满足：

* 首页 `Continuing / Recently Added / Recently Finished` 来自本地库
* 库页 tab / filter / sort 来自本地库
* 详情页内容来自真实 `mediaItemId`
* 删除或不存在的条目不能再 fallback 到 demo 详情，要给明确空状态 / not-found 状态

### R3 `/add` 从占位页升级为最小本地创建入口

WP3 里 `/add` 只是阶段2占位页，但阶段1父任务要求“本地可新增、编辑、删除记录”，所以 WP4 要把它补成 **最小本地创建流**。

首版只做本地手动添加，不做外部搜索：

* 必填：媒介类型、标题
* 可选：副标题、年份 / 发布时间、总集数 / 总页数 / 总时长等基础字段
* 创建成功后立即写入 `media_items` + 默认 `user_entries`
* 创建后可跳转详情，或返回库页 / 首页立刻可见

Phase 2 仍可在同一路由上继续叠加 Bangumi 搜索与快捷添加，不推翻本轮结构。

### R4 详情页本地记录动作要原地完成

详情页首屏内完成这些核心动作：

* 状态修改
* 评分修改
* 进度修改
* 私人笔记编辑与保存

要求：

* 不要求用户跳多个页面
* 保存后立即刷新当前页
* 首页 / 库页相关分区同步变化
* 交互保持 WP3 的桌面编辑感，不退回默认 Material 表单页

### R5 状态、评分、进度要有明确本地规则

需要把现在的硬编码展示值改成真实规则：

* 评分沿用 `0-10` 整数分
* 状态沿用 `UnifiedStatus`
* 进度按媒介类型写到正确字段
  * `tv`：`currentEpisode`
  * `book`：`currentPage`
  * `movie`：`currentMinutes`
  * `game`：`estimatedPlayHours` / `currentMinutes` 先按“游玩时长”近似表达

状态字段的时间语义在本轮补齐：

* 首次进入 `inProgress` 时写 `startedAt`
* 进入 `done` 时写 `finishedAt`
* 从 `done` 改回其他状态时，清掉 `finishedAt`

### R6 详情页生命周期日志接到真实 `activity_logs`

WP2 已建 `activity_logs` 表，但还没有读写链路。

WP4 要补齐：

* 新增条目
* 状态变更
* 评分变更
* 进度变更
* 笔记编辑
* 标记完成

以上动作都要落到 `activity_logs`，详情页右侧 `LIFECYCLE LOG` 读取真实数据，不再显示 demo 常量。

### R7 标签与自定义列表做最小可用接入

利用 WP2 已有 `TagRepository` / `TagDao` / `ShelfRepository` / `ShelfDao`：

* 详情页展示当前条目的标签和所属列表
* 新建 / 编辑时允许最小标签录入，并允许把条目挂到一个或多个列表
* 至少支持一个用户自定义列表的快速创建与挂接
* 没有标签或列表时走 calm empty state

本轮只做“够用”的标签 / 列表链路，不扩成独立管理中心。

### R8 删除链路要收口

利用 WP2 已有 `MediaRepository.softDelete()`：

* 详情页提供删除入口
* 删除后条目从首页 / 库页消失
* 已删除条目的详情路由不崩溃，展示 not-found / 已删除空状态

### R9 空状态和轻反馈要覆盖首次使用主路径

至少覆盖这些状态：

* 首次启动，库为空
* 首页某个分区为空
* 详情没有笔记 / 没有日志 / 没有简介
* 路由指向不存在条目
* 本地保存成功

反馈要求：

* 优先提示“已保存到本地”
* 轻提示，不打断用户继续记录
* 视觉遵守已有 `EmptyState` / Stitch token 约束

### R10 保持 WP3 的 UI 适配边界，不把页面改回数据拼装器

本轮虽然要联调真实数据，但仍要遵守：

* 页面层不直接调 DAO
* 读写逻辑留在 feature data / controller / repository
* `PosterViewData` 仍是 shared widgets 的稳定输入
* WP3 已抽出来的 `EmptyState`、`PosterCard`、`PosterWrap` 不被反向打散

## Acceptance Criteria

### 功能验收

* [ ] 首次进入空库时，首页 / 库页显示可读空状态，并能进入本地创建流
* [ ] 通过 `/add` 最小表单可成功创建本地条目
* [ ] 新建条目后，库页能看到该条目，首页 `Recently Added` 能看到该条目
* [ ] 详情页状态修改后，首页 `Continuing / Recently Finished` 与库页状态筛选立刻反映变化
* [ ] 详情页评分、进度、笔记修改后刷新页面仍能回显
* [ ] 详情页 `LIFECYCLE LOG` 显示真实本地日志，不再使用 demo 常量
* [ ] 删除条目后，该条目从首页 / 库页移除，详情路由展示 not-found / 已删除空状态
* [ ] 不存在 `mediaId` 时详情页不 crash，不 fallback 到 `DemoData.detailItem`
* [ ] 没有封面图的本地条目仍能以稳定占位海报正常显示
* [ ] 标签 / 自定义列表挂接后详情页可立即回显

### 数据验收

* [ ] `user_entries.status / score / notes / startedAt / finishedAt` 按规则更新
* [ ] `progress_entries` 只写对应媒介类型需要的字段
* [ ] `activity_logs` 记录新增、状态、评分、进度、笔记相关事件
* [ ] 软删除后条目查询结果不可见，但 `deletedAt` 已标记
* [ ] 标签可创建、挂接并在详情页展示
* [ ] 自定义列表可创建、挂接并在详情页展示

### 质量验收

* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过
* [ ] 至少补一组“空库 -> 新建 -> 修改状态/评分/进度/笔记 -> 删除”主路径测试
* [ ] 若引入新的 view data / controller 模式，同步更新 `.trellis/spec/` 相关文档

## Definition of Done

* 代码、测试、手工验证都覆盖本地主链路
* Windows 桌面预览下，交互和视觉没有退回默认 Material 质感
* PRD 里定义的本地闭环能从空状态完整走通一次
* 相关 spec / notes 已补齐，后续 WP5 回归时不需要重新猜这轮设计

## Technical Approach

### 1. 与前置任务衔接

**WP1 提供的产物，本轮直接复用：**

* `lib/shared/theme/app_theme.dart`
* `lib/shared/widgets/empty_state.dart`
* `lib/shared/widgets/poster_card.dart`
* `lib/shared/widgets/poster_wrap.dart`

**WP2 提供的产物，本轮接成真实读写链路：**

* `lib/shared/data/app_database.dart`
* `lib/shared/data/repositories/media_repository.dart`
* `lib/shared/data/repositories/user_entry_repository.dart`
* `lib/shared/data/repositories/progress_repository.dart`
* `lib/shared/data/repositories/tag_repository.dart`
* `lib/shared/data/repositories/shelf_repository.dart`
* `lib/shared/data/tables/activity_logs.dart`

**WP3 提供的产物，本轮不推翻，只替换实现：**

* `lib/features/home/data/home_view_data.dart`
* `lib/features/library/data/library_view_data.dart`
* `lib/features/detail/data/detail_view_data.dart`
* `lib/features/add/presentation/add_entry_page.dart`
* `lib/app/router/app_router.dart`

### 2. 读链路

保留 WP3 的 feature data source 边界，但把静态 `Provider` 升级成真实本地数据 provider。

建议形状：

* 首页：`StreamProvider<HomeViewData>`
* 库页：`StreamProvider.family<LibraryViewData, LibraryQuery>`
* 详情页：`StreamProvider.family<DetailViewData?, String>`

其中 `DetailViewData` 需要由这些数据拼装：

* `MediaItem`
* `UserEntry`
* `ProgressEntry?`
* `List<Tag>`
* `List<ActivityLog>`

要点：

* 缺失 `ProgressEntry` 时不能报错，要按“尚未开始记录进度”处理
* 缺失条目或条目已软删除时，provider 返回空态模型或 `null`
* 页面只消费 view data，不消费底层表对象

### 3. 写链路

增加 feature 级 controller / command provider，页面只触发动作，不直接写 repository。

建议拆分：

* `add_entry_controller.dart`：本地创建
* `detail_actions_controller.dart`：状态 / 评分 / 进度 / 笔记 / 删除

写入顺序：

1. 更新 repository / DAO
2. 追加 activity log
3. 返回本地保存成功反馈
4. 由 watch provider 自动把首页 / 库页 / 详情页刷新出来

### 4. Activity Log

本轮新增 `ActivityLogDao`（必要时再配 `ActivityLogRepository`），不靠 `updatedAt` 反推历史。

原因：

* 详情页右栏本来就有明确 `LIFECYCLE LOG` 容器
* WP2 已预留 `activity_logs` 表
* 追加日志比事后推断更稳定，也更利于 Phase 3 同步

### 5. `/add` 路由复用

不新增新路由，直接把 WP3 的占位 `/add` 升级为最小本地创建页。

这样有两个好处：

* 首页 / 库页空状态 action 不用再改路径
* Phase 2 之后要加 Bangumi 搜索时，可以在同一路由继续增强，不拆用户心智

### 6. 库页映射修正

接真实数据时要补两处 WP2 / WP3 之间的缝：

* `LibraryMediaType.movies` 实际应映射为 `movie + tv`，不能只查 `movie`
* UI 现在有 `Year` 排序，但 `MediaDao.watchLibrary()` 还没支持 `releaseDate` 排序，需要补上

状态筛选也要做 UI 文案到 `UnifiedStatus` 的明确映射，而不是直接拿展示文案查库。

### 7. 无封面本地条目的占位策略

本地手动创建不会天然带 `posterUrl`。

因此本轮不改 schema，加一层 adapter 解决：

* `PosterViewData` 继续吃 `posterColor / posterAccentColor`
* live adapter 按 `mediaType + title hash` 生成稳定占位色
* 后续 Phase 2 如果拿到 Bangumi 封面，再优先用真实封面

这样能保住 WP3 已经成型的海报墙视觉，不把本地条目退化成纯文本列表。

### 8. 轻反馈

保存成功提示优先走一套安静的本地 toast / floating snackbar。

要求：

* 不挡住详情编辑主区
* token 走 `AppColors` / `AppRadii` / `AppSpacing`
* 不引入亮色系统提示条风格

## Decision (ADR-lite)

### D1 继续沿用 WP3 的 view data adapter 边界

**Context**：
WP3 已经把页面层和共享组件层隔开。如果 WP4 直接让页面吃 DAO / table，会把前一轮抽象全部打回去。

**Decision**：
保留 `HomeViewData` / `LibraryViewData` / `DetailViewData`，只替换底层实现。

**Consequences**：
本轮要多写一层 adapter，但后续接 Bangumi / sync 时改动面更小。

### D2 `/add` 本轮先承担本地最小创建，Phase 2 再增强搜索

**Context**：
WP3 把 `/add` 留成占位，但阶段1父任务已经要求本地新增闭环。

**Decision**：
WP4 先把 `/add` 做成本地创建页，不做外部搜索；Phase 2 在同一路由继续增强。

**Consequences**：
本地 MVP 能闭环；后续不会多出第二套“添加入口”。

### D3 生命周期日志走 append-only 表，不靠字段反推

**Context**：
单靠 `updatedAt` 无法稳定还原“改状态、改进度、改笔记”的时间线。

**Decision**：
所有关键记录动作都追加 `activity_logs`。

**Consequences**：
写路径会多一步，但详情页历史区和后续同步都更稳。

### D4 本地无封面条目用稳定占位海报，不加新表字段

**Context**：
Phase 1 本地创建不应该为了海报视觉去提前设计图片上传系统。

**Decision**：
保留现有 `PosterViewData` 结构，在 adapter 层生成稳定占位色。

**Consequences**：
Phase 1 视觉完整；Phase 2 有真实封面后可无缝替换。

### D5 标签与自定义列表都做最小可用，不扩成独立管理中心

**Context**：
WP2 已有 `TagRepository` / `ShelfRepository`，父任务和阶段1 PRD 也把“列表、标签”列进了本地闭环范围。但 WP3 页面骨架只给了标签展示位，没有列表管理面板。

**Decision**：
本轮把标签链路和自定义列表最小链路一起接通；至少提供详情页展示、快速创建、挂接 / 取消挂接。不扩成独立列表页、复杂排序或批量管理。

**Consequences**：
阶段1 对“列表、标签”的本地闭环要求在本任务内收口；后续若要做列表管理中心，再单独拆任务。

## Implementation Plan (small PRs)

### PR1：真实本地读链路

* Home / Library / Detail 的 live provider
* `DemoData` 从主页面读链路退出
* not-found / deleted / empty 的 view data 收口
* 无封面占位海报策略
* 库页类型 / 排序映射修正

### PR2：本地创建与详情动作

* `/add` 最小本地创建页
* 状态 / 评分 / 进度 / 笔记 controller
* 本地保存轻反馈
* 详情页真实编辑交互替换硬编码展示值

### PR3：日志、标签 / 列表、删除与验证

* `activity_logs` 读写链路
* 标签 / 自定义列表最小接入
* 软删除入口与路由收口
* widget / repository / flow 测试
* `.trellis/spec/` 更新

## Out of Scope

* Bangumi 搜索、匹配、绑定、快捷添加
* WebDAV / S3-compatible 同步
* `deviceId` 持久化和真实跨设备标记
* 自定义列表高级管理 UI（独立列表页、排序、批量管理），已拆到 `04-20-followup-list-management`
* 海报上传、裁剪、本地图片管理
* 批量编辑、拖拽排序、快捷键体系
* Rich review、重刷次数、长评系统

## Technical Notes

### 已阅读文件

* `.trellis/tasks/04-18-flutter-media-tracker/prd.md`
* `.trellis/tasks/04-19-phase1-local-core/prd.md`
* `.trellis/tasks/archive/2026-04/04-19-phase1-wp2-local-data/prd.md`
* `.trellis/tasks/archive/2026-04/04-19-phase1-wp3-windows-shell-pages/prd.md`
* `.trellis/spec/frontend/design-system.md`
* `.trellis/spec/frontend/component-guidelines.md`
* `.trellis/spec/frontend/state-management.md`
* `.trellis/spec/frontend/quality-guidelines.md`

### 当前代码现状

* `lib/features/home/data/home_view_data.dart` 仍返回 `DemoHomeViewDataSource`
* `lib/features/library/data/library_view_data.dart` 仍返回 `DemoLibraryViewDataSource`
* `lib/features/detail/data/detail_view_data.dart` 仍返回 demo 聚合，并在 id 不存在时 fallback 到 `DemoData.detailItem`
* `lib/features/detail/presentation/detail_page.dart` 的状态、评分、进度、按钮都是硬编码展示
* `lib/features/add/presentation/add_entry_page.dart` 还是 phase2 placeholder
* `lib/shared/data/tables/activity_logs.dart` 已存在，但没有 DAO / repository / UI 读写链路
* `lib/shared/data/repositories/media_repository.dart` 已有 `createItem()` / `softDelete()` 和列表查询
* `lib/shared/data/repositories/user_entry_repository.dart` / `progress_repository.dart` 已有基础写接口，但没有把状态时间语义和 activity log 补齐
* `lib/shared/data/repositories/shelf_repository.dart` 已有基础接口，但当前没有详情页列表展示和挂接 UI

### 已识别的关键缝隙

* `MediaDao.watchLibrary()` 还不支持 `releaseDate` 排序
* `LibraryMediaType.movies` 与底层 `MediaType.movie / tv` 不是 1:1
* `PosterViewData` 需要颜色，但本地 schema 没有 poster color 字段
* `ProgressDao` 只有按 `mediaItemId` 取单条的能力，详情聚合时要处理“尚无进度记录”的空分支
* 当前仓储里的 `_getDeviceId()` 仍返回空字符串，这轮不处理跨设备语义，只保证本地可用
* shelf list 当前只有数据层能力，没有最小可见管理入口

### 本轮主线

```text
[WP4 本地主链路] ──┬── 空状态入口 ──┬── /add 最小本地创建
                    │                └── 创建后跳详情/回库页
                    ├── 本地读链路 ──┬── Home/Library live provider
                    │                └── Detail 聚合 view data
                    ├── 详情动作 ────┬── 状态/评分/进度/笔记
                    │                └── 删除与轻反馈
                    └── 生命周期 ────┬── activity_logs 追加写入
                                     └── Detail 日志回显
```
