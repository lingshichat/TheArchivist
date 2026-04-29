# 重新设计 lists 页面

## Goal
重新设计 lists 页面的视觉表现，使其与整体暗色主题（mint accent #5EEAD4）协调一致，提升视觉层次感和用户体验。

## Requirements

### 1. ShelfCard 重新设计
- 移除 HSL 彩色头像（在暗色主题下过于突兀）
- 采用暗色主题设计语言：surfaceContainerLow 背景 + 暗色渐变装饰
- 左侧使用 mint accent 装饰元素（垂直线或图标）
- 更大的标题（Manrope），更好的排版层次
- 项目数量使用 metadata 风格（Inter, uppercase, tracked）
- Hover 效果：抬升 + 阴影 + surface 变亮 + 左侧 accent 条变亮（180-240ms, easeOutCubic）
- 底部添加微妙的装饰线

### 2. ListsCenterPage 改进
- 添加页面 header 区域："Lists" 标题 + 描述文案
- 显示列表数量统计
- 改进网格布局和间距
- 空状态使用共享 EmptyState widget
- 保持桌面优先的密集布局

### 3. ListDetailPage 改进
- 改进头部设计，更像 Hero Banner
- 更好的操作按钮布局
- 改进排序选择器视觉
- 保持与整体设计语言一致

## Acceptance Criteria
- [ ] ShelfCard 使用暗色主题 token，无 HSL 彩色头像
- [ ] ShelfCard hover 有多重反馈（lift + shadow + surface shift）
- [ ] ListsCenterPage 有 header 区域和统计信息
- [ ] ListDetailPage 头部视觉改进
- [ ] 所有改动使用共享 theme token（AppColors, AppSpacing, AppRadii）
- [ ] flutter analyze 通过
- [ ] 不使用 stock Material Card/ListTile
- [ ] 不使用 glass/gradient 在普通卡片上
- [ ] 遵循 No-Line 规则（用 tonal layering 替代 divider）

## Technical Notes
- 修改文件：
  - `lib/features/lists/presentation/shelf_card.dart`
  - `lib/features/lists/presentation/lists_center_page.dart`
  - `lib/features/lists/presentation/list_detail_page.dart`
- 不修改数据层或路由
- 保持现有交互逻辑不变
