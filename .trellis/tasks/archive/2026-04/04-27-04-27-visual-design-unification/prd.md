# brainstorm: 前端视觉设计统一性 — The Archivist 深色主题重塑

## Goal

将 The Archivist 从浅色文档风格转向深色媒体库质感，以 Hills/Yamby 为视觉参考，让应用更像"个人媒体档案空间"而非"数据管理工具"。

## What I already know

* 项目已有较完整的 Material 3 自定义主题系统。
* Design tokens: `AppColors`、`AppSpacing`、`AppRadii`、`AppTextStyles` 统一管理。
* 全局 Theme 在 `lib/shared/theme/app_theme.dart`。
* 所有页面使用统一的 `AppTopBar` 组件。
* 当前为浅色主题（`#F9F9FB` 背景 + 深青绿 `#426464` 强调色）。
* Dark 主题令牌已定义但组件级配置不完整。
* **用户决策：转向深色主题，参考 Hills/Yamby 的媒体库质感。**

## Hills / Yamby 视觉语言总结

* **深色基底**：近黑/深灰背景，让媒体图片成为绝对视觉焦点。
* **内容优先**：大面积海报/封面，信息为辅。
* **沉浸感**：详情页顶部有大面积背景图（backdrop），文字叠加在图片上。
* **强调色鲜明**：Hills 用浅紫，Yamby 用粉红，在深色背景上很醒目。
* **卡片有质感**：圆角适中，卡片间有明确间距。
* **信息层次清晰**：大图 → 标题 → 元信息 → 详细内容。

## Decision (ADR-lite)

**Context**: 用户希望 The Archivist 从"档案工具感"转向"媒体库感"。
**Decision**: 全面转向深色主题，参考 Hills/Yamby 的视觉语言。
**强调色选择**: 薄荷青 `#5EEAD4`（用户选定）。与当前深青绿有延续性，在深色背景上醒目清新。
**Consequences**:
  * 需要重新定义整套颜色令牌。
  * 首页、Library、详情页的布局需大幅调整。
  * 这是一个全局性改动，影响几乎所有页面。
  * Windows 桌面端有更大屏幕，不能完全照搬移动端布局。

## Requirements

* **R1: 深色主题系统**
  * 重新定义 `AppColors` 深色配色方案。
  * 主背景色应接近黑色/极深灰（参考 Hills）。
  * 文字颜色需保证可读性（WCAG 标准）。
  * 强调色需要在深色背景上足够醒目。

* **R2: 首页重塑**
  * 增加视觉焦点区域（如"正在观看"的大横幅卡片）。
  * 媒体卡片更大、更有存在感。
  * 减少纯信息密度，增加内容展示面积。

* **R3: Library 页重塑**
  * 网格卡片布局，海报为主。
  * 筛选/排序控件视觉降噪。

* **R4: 详情页重塑**
  * 顶部大面积背景图/海报（backdrop 风格）。
  * 信息层次：图片 → 标题 → 元数据 → 操作按钮 → 详细内容。
  * 参考 Hills 详情页布局。

* **R5: 全局组件调整**
  * AppTopBar 适配深色主题。
  * 卡片圆角、阴影/边框调整。
  * EmptyState、LoadingState 适配深色。

* **R6: 字体与排版**
  * 标题字体可考虑更有张力的选择（Hills 使用粗体大标题）。
  * 信息层级通过字号/字重/颜色区分。

## Acceptance Criteria

* [ ] 深色主题在所有页面一致应用，无残留浅色元素。
* [ ] 首页有明显的视觉焦点区块。
* [ ] Library 页以海报网格为主视觉。
* [ ] 详情页顶部有大面积媒体图片展示。
* [ ] `flutter analyze` 无新增 error / warning。
* [ ] 所有页面在 Dark 模式下视觉一致。

## Definition of Done

* 所有页面适配深色主题。
* 新设计在 Windows 桌面端展示效果良好。
* Lint / analyze 通过。

## Out of Scope

* 暂不做移动端适配（布局以桌面端为主）。
* 暂不改业务逻辑，仅改视觉呈现。
* 暂不做动画/过渡效果的重设计。

## Technical Notes

* `lib/shared/theme/app_theme.dart` — 全局 Theme
* `lib/shared/theme/app_colors.dart` — 颜色令牌（需重新定义）
* `lib/shared/theme/app_theme.dart` — Dark theme 组件配置补全
* `lib/shared/widgets/app_top_bar.dart` — 顶部栏适配
* `lib/shared/widgets/poster_card.dart` — 海报卡片重塑
* `lib/shared/widgets/empty_state.dart` — 空状态适配
* `lib/features/home/presentation/home_page.dart` — 首页布局重塑
* `lib/features/library/presentation/library_page.dart` — Library 布局重塑
* `lib/features/detail/presentation/detail_page.dart` — 详情页布局重塑
* `lib/features/settings/presentation/settings_page.dart` — 设置页适配

## Implementation Plan

建议分 3 个 PR 逐步推进：

* **PR1: 深色主题基础设施**
  * 重新定义 `AppColors` 深色配色。
  * 补全 `AppTheme` Dark 主题组件配置。
  * 全局组件（AppTopBar、EmptyState、Loading）适配。
  * 验证所有页面无残留浅色元素。

* **PR2: 页面布局重塑**
  * 首页增加视觉焦点区块。
  * Library 网格卡片布局调整。
  * 详情页增加 backdrop 风格头部。
  * PosterCard 组件重塑。

* **PR3: 细节打磨**
  * 字体层级优化。
  * 间距/圆角微调。
  * 边界情况处理（长标题、无图片等）。
