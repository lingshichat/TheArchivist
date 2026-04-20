# 阶段1-WP3：Windows 首页、库页、详情页骨架

## Goal

把 Windows 首版的主界面和核心页面骨架补齐，形成可演示的桌面工作面。本轮在 WP1（shell + theme）和 WP2（Drift 本地数据）的基础上，让 home / library / detail 三页具备验收所要求的交互能力（tab 切换、filter 下拉）和空状态，并预先做一轮轻量重构（统一 poster 组件、为 detail 支持 `/detail/:id` 路由），为 WP4 接入数据做好前置。

本轮**不做**数据联调（不接 Drift），只准备好 UI 侧的适配层和空态分支，让 WP4 能直接换数据源。

## Requirements

- **R1 空状态占位**：home（三个 poster section 空态分支）、library（tab 无对应内容时空态）、detail（非 `DemoData.detailItem` 的条目，其 synopsis / notes / lifecycle 走空态）都要有符合 Stitch "quiet editorial" 风格的占位
- **R2 Library tabs 状态化**：Movies / Books / Games 三 tab 能切换选中视觉；tab 状态驱动 grid 内容显示（骨架阶段 Movies 显全量 demo，Books / Games 显空态）
- **R3 Library filters 可点击**：Status / Sort 两个下拉能弹 menu、能选中值并更新按钮显示（骨架阶段不真正过滤）
- **R4 `/detail/:id` 路由**：详情页接收 `mediaId` 路径参数，从 demo 数据 lookup；id 不存在时 fallback 到 `DemoData.detailItem`，不崩溃
- **R5 Home / Library poster 能跳转到对应 id 的详情**：当前是无参跳 `/detail`，改成 `/detail/<slug(title)>`
- **R6 统一 poster 组件族**：消除 home_page 的 `_HomePosterTile` / `_FinishedPosterTile` 和 library_page 的 `_LibraryPosterTile` 三处重复，统一用 `shared/widgets/poster_card.dart`，配合 `PosterCardVariant` 枚举区分视觉变体
- **R7 引入 `PosterViewData` 轻量 view model**：符合 component-guidelines "Pass domain-light view data into reusable widgets"；demo 侧用 `toPosterView()` 适配，WP4 再把 Drift `MediaItem` 适配过来
- **R8 不违反 Stitch 视觉契约**：空态和新增交互元素的颜色 / 半径 / 字号都走 `AppColors` / `AppRadii` / `AppSpacing` / theme textStyles，不引入 ad hoc 常量；空态用 surface 分层不用强边框
- **R9 View data source 抽象层**：home / library / detail 三页通过 Riverpod provider 获取 view data；接口位于 `lib/features/<feature>/data/`，demo 版实现返回 `DemoData` 的数据。WP4 只需提供新 impl，UI 不改
- **R10 `/add` 路由占位**：新增 `AppRoutes.add = '/add'`，`AddEntryPage` 作为 placeholder（一个"阶段 2 将实现"的 EmptyState）。Library 的 "+ 添加条目" 空态 action 跳 `/add`；home "打开媒介库" 仍跳 library
- **R11 Poster hover 动效**：PosterCard 加 MouseRegion + 200ms ease-out 的 subtle tonal shift（tile 稍微 lift + 海报边缘亮一度），符合 design-system motion contract "hover should shift tone first, not throw long-distance transforms"

## Acceptance Criteria

### 功能验收

- [ ] 首页三个 poster section 使用 `PosterWrap` + 三种 variant（continuing / compact / finishedOverlay），视觉与当前一致
- [ ] 点击首页任一 poster 跳转到 `/detail/<slug>`，正确渲染该条目
- [ ] 直接访问 `/detail/unknown-id` 不崩溃，fallback 渲染 `DemoData.detailItem`
- [ ] Library 页 Movies tab：显示 demo grid；切到 Books / Games tab：显示 `EmptyState`
- [ ] Library 页点击 Status / Sort dropdown：popup menu 弹出，选择后按钮文案更新
- [ ] Detail 页在非 `detailItem` 的 id 下，synopsis / notes / lifecycle 显示 `EmptyState`；在 `detailItem` 上显示完整内容
- [ ] sidebar Library 高亮在 `/detail/:id` 下仍然正确（基于 `startsWith('/detail')` 匹配）
- [ ] top-bar variant（Home / Library 黑色标题，Detail 强调色标题）在带 id 的详情路径下仍生效
- [ ] `/add` 路由能被访问（直接输入 URL 或从 library 空态 action 跳入），AddEntryPage 显示"阶段 2 将实现添加条目流程"的占位空态
- [ ] home / library / detail 页 body 中无 `import '../../../shared/demo/demo_data.dart'`（通过 feature 内 `<feature>_view_data_source.dart` 的 Riverpod provider 获取数据）
- [ ] poster tile 鼠标悬停时有可见的 200ms 过渡（subtle tonal shift + 轻微 lift 或 border 亮化），松开后回到原状态

### 视觉验收

- [ ] 空态视觉：`surfaceContainerLow` 底色 + `AppRadii.container` 圆角 + 居中 icon/title/body/action，整体保持 "quiet editorial" 不出现彩色渐变或强边框
- [ ] poster tile 视觉（三 variant）与当前 demo 截图级一致，不因重构产生漂移
- [ ] Library filter dropdown 开合与视觉不破坏 Stitch "No-Line Rule"

### 代码健康度

- [ ] `PosterViewData` 定义不包含任何 demo / Drift 特有字段（保持 domain-light）
- [ ] `PosterCard` / `PosterArt` / `PosterWrap` 不再 import `demo_data.dart`
- [ ] `home_page.dart` / `library_page.dart` 不再定义本地 poster tile 私有 widget
- [ ] `flutter analyze lib test` 无新增 warning

## Definition of Done

- 本地 `flutter analyze lib test` 通过
- 本地 `flutter test` 通过（WP3 不强制新增 widget test，但既有测试不能被破坏）
- 本地 `flutter run -d windows` 可启动，手动走完验收清单
- 没有在 `lib/` 下引入 new 硬编码颜色 / 半径
- `CLAUDE.md` 或现有 spec 若因 PosterViewData / EmptyState 浮现新约定，更新到 `.trellis/spec/frontend/component-guidelines.md`

## Technical Approach

### 架构概要

```
lib/shared/widgets/
├── poster_view_data.dart   # NEW: 轻量 view data + PosterStatusTone enum
├── empty_state.dart        # NEW: 空态组件
├── poster_card.dart        # MOD: 改接 PosterViewData + PosterCardVariant + hover
├── poster_art.dart         # MOD: 改接 PosterViewData
└── poster_wrap.dart        # MOD: 改接 List<PosterViewData> + variant + onItemTap(v)

lib/shared/demo/demo_data.dart     # MOD: 加 id getter + toPosterView + lookupById
lib/app/router/app_router.dart     # MOD: /detail/:id + /add + detailFor helper

lib/features/home/
├── data/home_view_data.dart            # NEW: HomeViewData + HomeViewDataSource + demo impl + provider
└── presentation/home_page.dart         # MOD: 读 provider + PosterWrap + EmptyState 分支

lib/features/library/
├── data/library_view_data.dart         # NEW: LibraryViewDataSource + demo impl + provider
└── presentation/library_page.dart      # MOD: StatefulWidget + enum + PopupMenu + 读 provider

lib/features/detail/
├── data/detail_view_data.dart          # NEW: DetailViewDataSource + demo impl + provider
└── presentation/detail_page.dart       # MOD: 接 mediaId + 通过 provider 取 + 空态分支

lib/features/add/
└── presentation/add_entry_page.dart    # NEW: 占位页（EmptyState "Coming soon"）
```

### 关键设计

**PosterViewData** (`lib/shared/widgets/poster_view_data.dart`)：

```dart
enum PosterStatusTone { primary, secondary, tertiary, muted }

class PosterViewData {
  const PosterViewData({
    required this.id,
    required this.title,
    required this.mediaLabel,
    required this.posterColor,
    required this.posterAccentColor,
    this.subtitle,
    this.year,
    this.statusLabel,
    this.statusTone = PosterStatusTone.secondary,
  });
  // fields...
}
```

**PosterCardVariant** 枚举取代原 `showSubtitle` / `showFooter` 布尔：
- `continuing` — home Continuing 用，mediaLabel accent + title 大号
- `compact` — home Recently Added 用，小号紧凑
- `finishedOverlay` — home Recently Finished 用，status pill 覆盖海报上
- `libraryFooter` — library grid 用，title + (status pill + year) 底部行

**EmptyState** (`lib/shared/widgets/empty_state.dart`)：`Container` 单元 + optional icon + title + body + optional ghost-border action。视觉走 `surfaceContainerLow` + `AppRadii.container`，严格遵守 No-Line / No-Gradient。

**路由**：`AppRoutes.detail` 保留为基路径 `/detail`；新增 `AppRoutes.detailFor(String id)` 生成 `/detail/$id`；go_router 的 `GoRoute(path: '${AppRoutes.detail}/:id')` 解析 pathParameter 注入 DetailPage。shell 的 `_isLibrarySelected` 用 `startsWith` 仍然 work。

**DemoMediaItem.id**：用 title 做 slug 的计算属性，避免手工改 20+ const 构造。`DemoData.lookupById` 扫所有列表 + detailItem。

**Detail 空态策略**：不把 notes / lifecycle / tags / synopsis 下放到每条 `DemoMediaItem`（改动面太大），而是判断 `item.id == DemoData.detailItem.id`：命中则显示原有硬编码内容，否则走 EmptyState。这在骨架阶段等价于"只有 detailItem 有完整内容"，符合"真实数据待 WP4"的定位。

**Library tab 过滤策略**：骨架阶段不对 demo mediaLabel 做严格匹配（demo 里用的是 Cinematography / Research / Audio 这种杂值，和 Movies/Books/Games 对不齐）。直接让 Movies 显全量 libraryItems、Books / Games 显空态。WP4 接真数据时再按 `MediaType` enum 过滤。

**View data source 抽象层**：每个 feature 在 `lib/features/<feature>/data/` 下定义自己的 view data source 接口 + demo 实现 + Riverpod provider。形状：

```dart
// lib/features/home/data/home_view_data.dart
class HomeViewData {
  const HomeViewData({
    required this.continuing,
    required this.recentlyAdded,
    required this.recentlyFinished,
    required this.categories,
  });
  final List<PosterViewData> continuing;
  final List<PosterViewData> recentlyAdded;
  final List<PosterViewData> recentlyFinished;
  final List<CategoryViewData> categories;
}

abstract class HomeViewDataSource {
  HomeViewData load();
}

class DemoHomeViewDataSource implements HomeViewDataSource { ... }

final homeViewDataProvider = Provider<HomeViewData>((ref) {
  return DemoHomeViewDataSource().load();
});
```

Library 类似，但 load 签名为 `LibraryViewData load(LibraryMediaType type)` 或暴露 `bookshelfFor(type)` 方法。Detail 类似 `DetailViewData? fetchById(String id)`。

新增 `CategoryViewData`（home 用）— 与 `DemoMediaCategory` 1:1 映射，不含 demo 前缀。

**`/add` 路由**：
- `AppRoutes.add = '/add'`
- `GoRoute(path: AppRoutes.add, pageBuilder: ...)` 返回 `AddEntryPage`
- `AddEntryPage` 是 `StatelessWidget`，body 居中放一个 `EmptyState(title: 'Coming soon', body: '添加条目流程将在阶段 2 与 Bangumi 搜索一起实现。', icon: Icons.construction_outlined)`
- Library EmptyState 的 action "+ 添加条目" → `context.go(AppRoutes.add)`
- Home 空态 "打开媒介库" → `context.go(AppRoutes.library)`
- Detail Notes 空态 action "+ Add note" 保持 noop（不跳 /add，因为语义不同）
- sidebar 不新增 nav item（/add 是辅助路由，不在主导航中）

**Poster hover 动效**：
- `PosterCard` 改 StatefulWidget，持 `_hovered` 状态
- 用 `MouseRegion(onEnter / onExit: setState)` 检测
- 海报包装改 `AnimatedContainer(duration: 200ms, curve: Curves.easeOut)`，hover 时：
  - 轻微 lift：`Transform.translate(offset: hover ? Offset(0, -2) : Offset.zero)`
  - 海报 BoxDecoration border 从 transparent → `AppColors.outlineVariant.withValues(alpha: 0.2)`
  - 背景 tone 从 `surfaceContainer` → `surfaceContainerLowest`（轻微亮一度）
- 不用 InkWell hoverColor（它只能改 overlay，做不到 lift），但保留 InkWell 的 tap 行为

## Decision (ADR-lite)

### D1 PosterCard 用 variant 枚举而非多 bool

**Context**：原 PosterCard 已有 `showSubtitle` + `showFooter` 两个 bool，而要支持 4 种 variant（加 compact 和 finishedOverlay），bool 组合爆炸且语义模糊。

**Decision**：改用 `enum PosterCardVariant { continuing, compact, finishedOverlay, libraryFooter }`，内部 switch 分支渲染。

**Consequences**：API 更明确；每个 variant 的视觉差异集中在 PosterCard 一处，避免 home / library 各自维护。未来新增变体也只需加一条 enum + 一个 switch case。

### D2 detail 空态用 id 判断，不下放字段

**Context**：完整的 synopsis / notes / lifecycle / tags 只写在顶层 `DemoData.*` 常量上，不是 `DemoMediaItem` 字段。若下放到每条 item，需要改 20+ const 构造并补齐占位数据。

**Decision**：detail 页判断 `item.id == DemoData.detailItem.id`，仅在命中 showcase 时渲染完整内容，否则各区块走 EmptyState。

**Consequences**：骨架阶段仅 detailItem 有完整内容（符合实际——其他都是占位 demo）。WP4 接 Drift 后，每条 MediaItem 都会有真实 notes/progress/activity，这段判断自然被 repository 返回的实际数据取代。

### D3 PosterViewData 不预置 WP4 字段

**Context**：PosterViewData 理论上可以预留 coverUrl / progressPercent 等 WP4 需要的字段。但本轮 WP3 明确不做数据联调，预留会引入未验证的 API 面。

**Decision**：PosterViewData 只含当前 UI 实际用到的字段（id / title / mediaLabel / subtitle / year / statusLabel / statusTone / posterColor / posterAccentColor）。WP4 再按需增加。

**Consequences**：WP4 接入 Drift 时需要扩展 PosterViewData 并改适配层；改动集中在 shared/widgets 和 repository 适配处，影响面可控。

### D4 View data source 按 feature 本地放，不进 shared

**Context**：三个 feature 各有独立的 view data 形状（home 有四段 section、library 按 media type 过滤、detail 按 id 查单条）。放 shared 会形成一个"共享的 feature 数据接口目录"，既不能复用也污染 shared 语义。

**Decision**：每个 feature 在 `lib/features/<feature>/data/<feature>_view_data.dart` 下管自己的 view data + source + demo impl + Riverpod provider。shared 里只放 cross-feature 的 `PosterViewData`、`CategoryViewData`。

**Consequences**：feature 自管数据边界，WP4 要切数据源只动 feature 内部的 provider override（注入新 impl），不触 shared。代价是三个 feature 各有一套类似结构，接受这个轻度重复以换取边界清晰。

### D5 Hover 动效用 MouseRegion + AnimatedContainer，不用 InkWell hoverColor

**Context**：Flutter InkWell 的 hoverColor 只能做 overlay 色变，无法做 lift / scale / border 变化。Stitch motion contract 要求 "shift tone first, not throw long-distance transforms" 但也接受 "slight lift or scale"。

**Decision**：PosterCard 改 StatefulWidget，用 MouseRegion 捕捉 hover 状态，AnimatedContainer + Transform.translate 做 200ms ease-out 的 tone + lift 过渡。tap 行为仍由 InkWell 承担。

**Consequences**：PosterCard 从无状态变有状态，文件略微复杂化；但 hover 在 Windows 桌面端是核心交互，价值值得。

## Out of Scope

- 数据联调（把 Drift MediaItem / UserEntry / ProgressEntry 真接入 UI）— 归 WP4（本轮只准备抽象接口，不替换 demo impl）
- Bangumi 搜索、快捷添加流程 — 归阶段 2（`/add` 页面本轮仅占位）
- 跨端同步、WebDAV/S3 配置 — 归阶段 3
- sidebar nav item / brand / profile 抽出到 `shared/widgets/archivist_sidebar.dart` — 超范围，留给后续结构化重构
- `_ResponsiveGrid` / `PosterWrap` 的完全统一 — 仅改 poster tile 层，LayoutBuilder 算列逻辑保持原样
- `DetailPage` 按子 widget 拆文件（当前 650 行）— 超范围
- 复杂筛选器（多选 tag / 多字段 sort） — PRD 要求的是可点击骨架
- 窄屏（< 1280）完整响应式 — 当前假设 Windows 桌面宽度
- 深色主题针对空态的专门调整
- dark theme 下三种 variant 的视觉复检（dark theme 在 WP1 只定了底色，未做组件级适配）
- Detail Notes 空态 action 的真实跳转行为（本轮 noop）
- hover 动效的按键/触摸等价体验（Windows 桌面优先；触摸/移动端后续阶段考虑）

## Technical Notes

### 关键现状文件

- `lib/app/shell/app_shell_scaffold.dart` — sidebar 256px + 内容区按路由切 variant（`_isLibrarySelected` 用 startsWith）
- `lib/app/router/app_router.dart` — ShellRoute + 4 GoRoute，`AppRoutes.detail = '/detail'` 需改，新增 `/add`
- `lib/shared/widgets/app_top_bar.dart` — fixed-slot glass，已符合 Stitch contract，不改
- `lib/shared/widgets/poster_card.dart` — 需改 API，改 StatefulWidget 支持 hover
- `lib/shared/widgets/poster_wrap.dart` — 需改 API
- `lib/shared/widgets/poster_art.dart` — 需改接收类型
- `lib/shared/widgets/section_header.dart` / `section_card.dart` — 不动
- `lib/shared/demo/demo_data.dart` — 加 extension 和 lookup
- `lib/features/home/presentation/home_page.dart` — 去本地 tile，改用 provider + PosterWrap
- `lib/features/library/presentation/library_page.dart` — 改 StatefulWidget + provider
- `lib/features/detail/presentation/detail_page.dart` — 接 mediaId + provider

### 新增文件

- `lib/shared/widgets/poster_view_data.dart` — PosterViewData + PosterStatusTone enum
- `lib/shared/widgets/empty_state.dart` — EmptyState 组件
- `lib/shared/widgets/category_view_data.dart` — CategoryViewData（home 用，替代 DemoMediaCategory 的 UI 外露）
- `lib/features/home/data/home_view_data.dart` — HomeViewData + HomeViewDataSource + DemoHomeViewDataSource + homeViewDataProvider
- `lib/features/library/data/library_view_data.dart` — LibraryViewData + LibraryViewDataSource + demo impl + provider
- `lib/features/detail/data/detail_view_data.dart` — DetailViewData + DetailViewDataSource + demo impl + provider
- `lib/features/add/presentation/add_entry_page.dart` — 占位页

### Spec 约束

- `.trellis/spec/frontend/design-system.md`：No-Line / Glass 限 topbar / Gradient 限 primary emphasis / radius sm/card/container/floating/pill
- `.trellis/spec/frontend/component-guidelines.md`：pass domain-light view data、2+ 页复用就抽共享、variant 用显式状态而非推断
- `.trellis/spec/frontend/quality-guidelines.md`：禁 ad hoc 颜色 / 半径 / gutter，禁 ColorScheme.fromSeed 当最终源

### 依赖

- 依赖 `04-19-phase1-wp1-foundation-theme`（已归档）
- 与 `04-19-phase1-wp2-local-data`（已完成）的接入由 WP4 承担
- 本任务不修改 `lib/shared/data/**`（Drift 层）
