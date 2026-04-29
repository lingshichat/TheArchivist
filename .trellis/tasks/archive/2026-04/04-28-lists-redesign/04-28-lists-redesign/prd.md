# Lists 页面重设计

## Goal

将 Lists 页面从文字卡片网格升级为与 Home 页视觉语言一致的海报驱动卡片网格，复用现有的 PosterCard / PosterWrap / PosterArt 设计系统。

## Design Principles

1. **风格一致** — ShelfCard 的外形、比例、hover 动画、阴影、圆角与 Home 页的 PosterCard 完全一致
2. **语义清晰** — 通过 2×2 海报马赛克表达「这是一个包含多个项目的列表」
3. **复用优先** — 优先复用现有组件（PosterWrap、PosterArt 风格 fallback），避免重复造轮子

## Requirements

### 核心布局

**ShelfCard = PosterCard 外形 + 2×2 马赛克内部**

```
┌─────────────────┐  ← 2:3 比例海报区（与其他页面 PosterCard 一致）
│ ┌───┬───┐       │
│ │ 1 │ 2 │       │  ← 2×2 海报马赛克（列表内前 4 个项目）
│ ├───┼───┤       │
│ │ 3 │ 4 │       │
│ └───┴───┘       │
├─────────────────┤
│ 列表名称        │  ← 底部信息栏（与其他 PosterCard meta 一致）
│ 4 ITEMS    ✎ 🗑 │  ← 项目数 + hover 编辑/删除按钮
└─────────────────┘
```

- **海报区**：2:3 比例，与 PosterCard 完全一致
- **2×2 马赛克**：4 个等分 slot，slot 之间 1-2px 分隔线（surfaceContainerHighest 色）
- **空位处理**：用基于列表名称 hash 的渐变填充，风格与 PosterArt 的 fallback 一致（几何装饰元素）
- **空列表**：4 个 slot 全部显示渐变 fallback，不显示 "0 items" 字样（由底部信息栏表达）
- **底部信息栏**：列表名称（titleMedium · w700）+ 项目数（labelSmall · 大写 · subtleText）
- **Hover 状态**：
  - 卡片整体上移（AnimatedSlide offset -0.015）
  - 阴影加深（同 PosterCard）
  - 右上角显示编辑/删除按钮（同现有 ShelfCard）

### 数据层

- 扩展 `ShelfListCardViewData`，增加 `previewItems: List<ShelfPreviewItem>`（最多 4 个）
- `ShelfPreviewItem` 包含：`id`, `title`, `mediaType`, `posterUrl`
- 修改 `shelfListCenterProvider`：同时监听 shelves 和 shelf-media links 变化，加载每个列表的前 4 个项目
- 复用已有的 `PosterViewData` 的 `_paletteFor` 颜色生成逻辑（或基于列表名称 hash 的等效实现）

### 交互

- 点击卡片 → 进入 ListDetailPage
- Hover 时右上角显示编辑/删除按钮
- 编辑 → 重命名对话框
- 删除 → 确认对话框

### 响应式

- 使用 PosterWrap 的自适应列数逻辑
- `minColumns: 2`, `maxColumns: 5`, `minTileWidth: 170`
- `horizontalSpacing: AppSpacing.xxl`, `verticalSpacing: AppSpacing.xxl`
- 保持 staggered 入场动画（row * 60ms + col * 40ms）

### 保留不变

- 创建列表（对话框 + 按钮位置）
- Loading / Error / Empty 三种状态
- ListDetailPage 布局不变

## Acceptance Criteria

- [ ] ShelfCard 外形与 PosterCard 一致（2:3 比例、圆角、hover 动画、阴影）
- [ ] 卡片内部展示 2×2 海报马赛克
- [ ] 有封面时显示封面图，空位用渐变 fallback（基于列表名称 hash 取色）
- [ ] 底部信息栏显示列表名称和项目数
- [ ] Hover 时显示编辑/删除按钮
- [ ] 点击卡片正确跳转到详情页
- [ ] 使用 PosterWrap 的自适应列数和 staggered 入场动画
- [ ] 数据加载不出现 N+1 查询问题
- [ ] 空列表正确显示（4 个 fallback slot）

## Definition of Done

- 功能完整，所有 acceptance criteria 满足
- 代码通过 lint / typecheck
- 无性能回退（列表多时加载流畅）
- 视觉上与 Home 页风格一致

## Out of Scope

- ListDetailPage 详情页布局不变
- 新增排序/筛选/标签功能
- 列表拖拽排序
- 海报点击放大预览

## Technical Approach

### UI 架构

```
ListsCenterPage
  └── PosterWrap<ShelfListCardViewData>  (复用 PosterWrap 的列数和动画逻辑)
        └── ShelfCard
              ├── AspectRatio(2/3)         (海报区，与 PosterCard 一致)
              │     └── Stack
              │           ├── _PosterMosaic (2×2 网格)
              │           └── _HoverActions (编辑/删除按钮)
              └── _CardMeta                  (列表名称 + 项目数)
```

### 复用清单

| 组件/模式 | 来源 | 复用方式 |
|----------|------|---------|
| 卡片外形（比例、圆角、hover、阴影） | PosterCard | 复制结构到 ShelfCard |
| 海报渲染 + fallback | PosterArt / PosterImage | 复用 CachedNetworkImage + 渐变 fallback 风格 |
| 自适应列数 + 入场动画 | PosterWrap | 复制 LayoutBuilder + staggered 逻辑到 ListsCenterPage |
| 颜色生成 | poster_view_data.dart `_paletteFor` | 复用或创建基于 hash 的等效实现 |

### 文件变更

- `lib/features/lists/presentation/shelf_card.dart` — 重写为 PosterCard 风格 + 2×2 马赛克
- `lib/features/lists/presentation/lists_center_page.dart` — 改用 PosterWrap 风格的自适应网格
- `lib/features/lists/data/lists_view_data.dart` — 扩展 view data + provider（保留当前改动）
- `lib/shared/data/daos/shelf_dao.dart` — `watchAllShelfLinks()`（保留当前改动）
- `lib/shared/data/repositories/shelf_repository.dart` — `watchAllShelfLinks()`（保留当前改动）

## Decision (ADR-lite)

**Context**: 当前列表卡片仅显示文字，与 Home 页海报驱动的视觉语言不一致。之前的实现（单张主海报 + 对角线 peek 海报）偏离了 2×2 马赛克的设计意图，视觉上像"斜插的书架"而非"内容集合"。

**Decision**: 采用 PosterCard 外形 + 2×2 内部马赛克的方案，严格复用现有设计系统的比例、动画、颜色和阴影。

**Consequences**: 需要重写 ShelfCard 和 ListsCenterPage 的布局逻辑，但 design token 和交互模式全部复用，视觉一致性最高。

## Technical Notes

- 关键参考文件：
  - `lib/shared/widgets/poster_card.dart` — hover 动画、阴影、圆角、边框的权威实现
  - `lib/shared/widgets/poster_wrap.dart` — 自适应列数和 staggered 入场动画
  - `lib/shared/widgets/poster_art.dart` — fallback 渐变风格参考
  - `lib/shared/widgets/poster_view_data.dart` — `_paletteFor` 颜色生成
- 2×2 网格可用 `GridView.count(crossAxisCount: 2, physics: NeverScrollableScrollPhysics())` 或直接用 `Row + Expanded` × 2 实现
- slot 分隔线用 `Container(color: AppColors.surfaceContainerHighest, width/height: 1)`
- fallback 渐变需与 PosterArt 风格一致：深色渐变 + 白色低透明度几何装饰（旋转矩形、圆形、底部线条）
