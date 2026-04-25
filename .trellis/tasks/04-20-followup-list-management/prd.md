# 后续增强：自定义列表管理中心与批量管理

## 目标

在 WP4 已经打通"列表最小创建、挂接、回显"的前提下，把自定义列表从"能用"收成"好用"。

这个任务不再负责阶段1的本地闭环兜底，而是承接后续增强：

- 独立列表页
- 列表详情页
- 排序与整理
- 批量挂接 / 移除
- 更完整的列表管理体验

## 来源

本任务从 `04-19-phase1-wp4-local-record-flow` 拆出。

拆分原则：

- **留在 WP4 的**：最小列表链路
  - 创建列表
  - 给条目挂接 / 取消挂接
  - 在详情页回显
- **拆到本任务的**：高级列表管理
  - 独立列表页
  - 排序
  - 批量管理
  - 更完整的列表编辑体验

---

## 范围

### R1 独立"列表中心"入口与页面

在现有 sidebar 导航中新增 **Lists** 入口，位于 Library 与 Settings 之间。

列表中心页面包含：

- 页面标题区：显示"Lists"标题和轻量统计（如"12 个自定义列表"）
- 新建列表按钮：始终可见的主操作入口
- 列表卡片网格：以卡片形式展示所有用户自定义列表（`kind = user` 且 `deletedAt isNull`）
- 每张卡片展示：
  - 列表名称
  - 条目数量
  - 最近更新/创建时间
  - 快速操作入口（编辑名称、删除）
- 空状态：没有自定义列表时展示友好的引导空状态

**设计约束**：
- 沿用 Stitch 视觉契约，页面密度与 Library 一致
- 卡片使用 `surfaceContainer` 底色，`sm` 圆角
- 不引入新的主色调，复用现有的 accent 体系
-  hover 效果保持 subtle tonal change

### R2 列表卡片 / 列表墙 / 列表目录

列表中心页面的卡片布局遵循以下规则：

- 桌面端：响应式网格，最小列宽 240px，每行 3-5 列
- 窄屏（< 768px）：单列卡片堆叠
- 卡片内部结构（自上而下）：
  - 列表图标或首字母缩略（稳定色生成）
  - 列表名称（Manrope bold）
  - 条目数量（Inter small, onSurfaceVariant）
  - 操作按钮区（编辑、删除图标按钮）
- 卡片点击进入列表详情页

### R3 列表详情页，展示该列表下的条目

新增 `/lists/:id` 路由，展示单个列表的内容。

页面结构：

- 顶部信息栏：
  - 返回列表中心按钮
  - 列表名称（可编辑）
  - 条目数量
  - 管理操作：重命名、删除列表、批量选择模式切换
- 条目展示区：
  - 以 `PosterWrap` 展示列表内所有条目
  - 支持排序切换（最近加入、名称、评分、状态）
  - 空状态：列表为空时展示"此列表暂无条目"引导
- 条目操作：
  - 单个条目：可移除出列表
  - 批量模式：多选后批量移除

**数据需求**：
- 需要新增 DAO 查询：按 `shelfListId` 查询关联的 `MediaItem`
- 关联查询需要支持排序（position、加入时间、标题、评分）
- 返回类型：`List<PosterViewData>` 或类似的适配类型

### R4 列表重命名、删除、基础元信息编辑

列表中心页和列表详情页都支持列表元信息编辑。

**重命名**：
- 点击编辑图标触发内联编辑或轻量对话框
- 验证：非空、不与现有列表重名（大小写不敏感）
- 限制：系统列表（`kind = system`）不可重命名
- 成功后轻反馈

**删除**：
- 点击删除图标触发确认对话框
- 确认后执行软删除（更新 `deletedAt`）
- 级联处理：删除列表时，同步软删除 `media_item_shelves` 中相关关联记录
- 成功后返回列表中心页
- 限制：系统列表不可删除

**注意**：本轮不扩展列表的额外元字段（如描述、封面、标签等），只支持名称编辑。

### R5 列表内条目排序

列表内条目支持多种排序方式：

| 排序方式 | 说明 | 实现依据 |
|---------|------|---------|
| 手动排序 | 用户自定义的顺序 | `media_item_shelves.position` |
| 最近加入 | 最近挂接到列表的时间 | `media_item_shelves.createdAt` |
| 标题 | 按条目标题字母序 | `media_items.title` |
| 评分 | 按用户评分降序 | `user_entries.score` |
| 状态 | 按观看/阅读状态分组 | `user_entries.status` |

**手动排序的 UI 策略**：
- 在列表详情页提供排序切换器（类似 Library 的 filter popup）
- 手动排序模式下，允许拖拽重排条目位置（桌面端优先）
- 拖拽后更新 `position` 字段
- 若拖拽实现成本高，可先用上下箭头按钮作为 fallback

**position 字段说明**：
- 当前 `media_item_shelves.position` 已有，默认值 0
- 需要实现 position 的批量重计算逻辑（类似链表间隔策略，避免频繁全表更新）

### R6 批量加入列表 / 移出列表

**场景 1：从 Library 批量加入列表**

- Library 页新增"批量选择"模式切换按钮
- 进入批量模式后，poster 卡片显示选择复选框
- 底部出现浮动操作栏：
  - "加入列表"：弹出列表选择器，可多选列表后批量挂接
  - "取消"：退出批量模式
- 已属于某列表的条目在选择器中显示已选状态

**场景 2：从列表详情页批量移出**

- 列表详情页的管理操作包含"批量选择"切换
- 进入批量模式后，条目显示选择复选框
- 底部浮动操作栏：
  - "移出列表"：批量软删除关联记录
  - "取消"：退出批量模式

**批量挂接的技术约束**：
- 批量挂接时，若条目已在目标列表中，跳过（幂等）
- 批量操作完成后，一次性刷新页面数据
- 操作失败时展示错误反馈，不部分成功（事务保障）

### R7 空列表空状态

空状态需要覆盖：

- **列表中心为空**：没有创建过任何自定义列表
  - 标题："No lists yet"
  - 副文案："Create your first list to organize titles into custom collections."
  - 操作："Create List" 主按钮
- **列表详情为空**：列表存在但其中没有条目
  - 标题："This list is empty"
  - 副文案："Add titles from the library or the detail page."
  - 操作："Open Library" 按钮

空状态视觉要求：
- 使用 `EmptyState` 组件
- 不显示默认 Material 数据表空状态
- 保持 calm、quiet 的编辑档案风格

### R8 列表维度的筛选、计数和轻量统计

列表中心页展示轻量统计：

- 总列表数
- 各列表的条目数量（实时计数，不缓存）

列表详情页展示：

- 列表内总条目数
- 按状态的分布（可选，作为后续增强点）

**计数实现**：
- 在 DAO 层提供按 `shelfListId` 统计关联条目的方法
- 计数排除已软删除的关联记录和已软删除的媒体条目

### R9 与现有 Home / Library / Detail 的视觉契约保持一致

所有新增页面和组件必须遵守：

- `.trellis/spec/frontend/design-system.md` 中的 Token 契约
- `.trellis/spec/frontend/component-guidelines.md` 中的组件规则
- 不使用默认 Material 3 chrome
- 保持 desktop-first 的密度和布局
- 保持 `Manrope` + `Inter` 字体层级

---

## 不包含

- WP4 的最小列表挂接链路
- Bangumi 同步
- 跨设备同步（虽然现有表结构已预留 sync 字段，但本轮不启用同步逻辑）
- 协作列表 / 分享列表
- 智能推荐列表
- 列表封面拼图、复杂拖拽动画
- 列表描述、封面图片等额外元字段
- 系统列表的管理（系统列表只读展示）

---

## 数据模型

### 现有模型（WP4 已提供）

**`shelf_lists` 表**：
| 字段 | 类型 | 说明 |
|------|------|------|
| id | text | 主键 |
| name | text | 列表名称 |
| kind | text | `system` 或 `user` |
| createdAt | datetime | 创建时间 |
| updatedAt | datetime | 更新时间 |
| deletedAt | datetime? | 软删除标记 |
| syncVersion | int | 同步版本 |
| deviceId | text | 设备标识 |
| lastSyncedAt | datetime? | 最后同步时间 |

**`media_item_shelves` 关联表**：
| 字段 | 类型 | 说明 |
|------|------|------|
| id | text | 主键 |
| mediaItemId | text | FK → media_items |
| shelfListId | text | FK → shelf_lists |
| position | int | 排序位置（默认 0） |
| createdAt | datetime | 创建时间 |
| updatedAt | datetime | 更新时间 |
| deletedAt | datetime? | 软删除标记 |
| syncVersion | int | 同步版本 |
| deviceId | text | 设备标识 |
| lastSyncedAt | datetime? | 最后同步时间 |

### 本轮需新增/调整

**DAO 层新增查询**：

```dart
// ShelfDao 新增

/// 按列表 ID 查询关联的媒体条目（带排序）
Stream<List<MediaItem>> watchMediaItemsByShelfId(
  String shelfListId, {
  String sortBy = 'position',
  bool descending = false,
});

/// 统计列表内有效条目数
Future<int> countMediaItemsByShelfId(String shelfListId);

/// 更新关联的 position
Future<void> updatePosition(
  String mediaItemId,
  String shelfListId,
  int position,
);

/// 批量更新 position
Future<void> batchUpdatePositions(
  List<({String mediaItemId, int position})> updates,
  String shelfListId,
);
```

**Repository 层新增**：

```dart
// ShelfRepository 新增

/// 获取列表内条目（带排序）
Stream<List<MediaItem>> watchShelfMediaItems(
  String shelfListId, {
  ShelfSortOption sortBy,
});

/// 统计列表条目数
Future<int> countShelfItems(String shelfListId);

/// 重命名列表
Future<void> renameShelf(String shelfListId, String newName);

/// 软删除列表（级联软删除关联）
Future<void> softDeleteShelf(String shelfListId);

/// 批量挂接条目到列表
Future<void> batchAttachToShelf(
  String shelfListId,
  List<String> mediaItemIds,
);

/// 批量移出条目
Future<void> batchDetachFromShelf(
  String shelfListId,
  List<String> mediaItemIds,
);

/// 更新条目在列表中的排序位置
Future<void> reorderShelfItems(
  String shelfListId,
  List<String> mediaItemIdsInOrder,
);
```

---

## 技术方案

### 1. 路由设计

新增路由：

```dart
abstract final class AppRoutes {
  // ... 现有路由 ...
  static const lists = '/lists';
  static const listDetail = '/lists/detail';

  static String listDetailFor(String id) => '$listDetail/$id';
}
```

路由规则：
- `/lists` → 列表中心页
- `/lists/detail/:id` → 列表详情页

ShellRoute 中新增：
- sidebar 新增 Lists 导航项
- top bar 标题：Lists
- 内容区 max width：1600px（与 Library 一致）

### 2. 状态管理

**读状态（StreamProvider）**：

```dart
// 列表中心
final shelfListCenterProvider = StreamProvider<List<ShelfListCardViewData>>((ref) {
  final repo = ref.watch(shelfRepositoryProvider);
  // watchAll + count per shelf
});

// 列表详情
final shelfDetailProvider = StreamProvider.family<ShelfDetailViewData, String>((ref, shelfId) {
  final repo = ref.watch(shelfRepositoryProvider);
  // watch shelf + watch media items
});
```

**写状态（Controller）**：

```dart
final shelfManagementControllerProvider = Provider<ShelfManagementController>((ref) {
  return ShelfManagementController(ref);
});

class ShelfManagementController {
  Future<void> createShelf(String name);
  Future<void> renameShelf(String id, String newName);
  Future<void> deleteShelf(String id);
  Future<void> batchAttach(String shelfId, List<String> mediaItemIds);
  Future<void> batchDetach(String shelfId, List<String> mediaItemIds);
  Future<void> reorderItems(String shelfId, List<String> orderedItemIds);
}
```

**页面局部状态**：
- 批量选择模式：`StatefulWidget` 局部状态
- 排序选项：`StatefulWidget` 局部状态
- 编辑对话框状态：`StatefulWidget` 局部状态

### 3. 页面结构

```
lib/
  features/
    lists/
      data/
        lists_view_data.dart          # ShelfListCardViewData, ShelfDetailViewData
        lists_controller.dart          # ShelfManagementController
      presentation/
        lists_center_page.dart         # 列表中心页
        list_detail_page.dart          # 列表详情页
        shelf_card.dart                # 列表卡片组件
        shelf_sort_selector.dart       # 排序选择器
        batch_selection_bar.dart       # 批量操作浮动栏
        list_picker_dialog.dart        # 列表选择器对话框
    library/
      presentation/
        library_page.dart              # 新增批量模式入口（本任务修改）
```

### 4. 批量选择模式设计

Library 页和 List Detail 页共享批量选择逻辑，建议抽离为可复用的 mixin 或 controller：

```dart
class BatchSelectionController extends ChangeNotifier {
  final Set<String> _selectedIds = {};
  bool _isActive = false;

  bool get isActive => _isActive;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool isSelected(String id) => _selectedIds.contains(id);

  void enterBatchMode();
  void exitBatchMode();
  void toggleSelection(String id);
  void selectAll(Iterable<String> ids);
  void clearSelection();
}
```

### 5. Position 排序策略

为避免每次拖拽都导致大量 position 重计算，采用间隔策略：

- 初始插入：`position = index * 1000`
- 拖拽到两个条目之间：`position = (prev.position + next.position) ~/ 2`
- 当间隔小于 10 时，触发全表重排（间隔恢复为 1000）

---

## 验收标准

### 功能验收

- [ ] Sidebar 新增 Lists 导航项，点击进入列表中心页
- [ ] 列表中心页展示所有用户自定义列表卡片，包含名称和条目数量
- [ ] 列表中心页空状态友好引导，提供创建列表入口
- [ ] 点击卡片进入列表详情页，展示该列表下的所有条目
- [ ] 列表详情页支持排序切换（手动/最近加入/标题/评分/状态）
- [ ] 列表详情页空状态清楚，提供返回 Library 的入口
- [ ] 用户可在列表中心页或详情页创建新列表
- [ ] 用户可重命名自定义列表（系统列表不可编辑）
- [ ] 用户可删除自定义列表，删除后列表从列表中心消失，关联记录被级联软删除
- [ ] Library 页支持批量选择模式，可将多个条目批量加入一个或多个列表
- [ ] 列表详情页支持批量选择模式，可将多个条目批量移出列表
- [ ] 批量操作完成后，相关页面数据自动刷新
- [ ] 手动排序模式下可调整条目顺序（拖拽或按钮），顺序持久化

### 数据验收

- [ ] `shelf_lists` 的软删除正确标记 `deletedAt`
- [ ] 列表删除时，`media_item_shelves` 关联记录同步软删除
- [ ] `media_item_shelves.position` 在排序调整后正确更新
- [ ] 批量挂接时，已存在的关联不重复创建（幂等）
- [ ] 批量移出时，关联记录执行软删除而非硬删除
- [ ] 重名验证在大小写不敏感的基础上工作

### 视觉验收

- [ ] 新增页面与 Home / Library / Detail 保持一致的视觉契约
- [ ] 不引入默认 Material 3 数据表或列表样式
- [ ] 卡片 hover / active 状态 subtle，符合 design-system.md
- [ ] 空状态使用 `EmptyState` 组件，文案 calm
- [ ] 批量操作栏使用 floating bar，不遮挡内容区过多空间
- [ ] 对话框/编辑框保持 ledger-like 最小风格

### 质量验收

- [ ] `flutter analyze lib test` 通过
- [ ] `flutter test` 通过
- [ ] 新增 shelf DAO 查询的单元测试
- [ ] 新增 shelf repository 批量操作的单元测试
- [ ] 新增列表中心页、列表详情页的 widget 测试（至少覆盖空状态和基本交互）
- [ ] 若引入新的 view data / controller 模式，同步更新 `.trellis/spec/` 相关文档

---

## 定义完成

- 代码、测试覆盖列表管理中心和列表详情页的主链路
- Windows 桌面预览下，新增页面交互和视觉没有退回默认 Material 质感
- PRD 中定义的列表管理功能能从列表中心完整走通一次（创建 → 添加条目 → 排序 → 批量移除 → 删除）
- 批量操作在 100 条数据量下响应流畅
- 相关 spec / notes 已补齐，后续 WP 回归时不需要重新猜这轮设计

---

## 技术方案决策

### D1 Sidebar 新增 Lists 导航项

**Context**：
列表管理是一个独立的功能域，与 Library（浏览全部）和 Settings（系统设置）职责不同。如果把它隐藏在 Library 内部，用户发现成本高。

**Decision**：
在 sidebar 一级导航中新增 Lists 入口，位于 Library 和 Settings 之间。

**Consequences**：
- AppShellScaffold 需要修改 sidebar 和 top bar 标题逻辑
- Lists 页与 Library 页有同级的信息架构地位

### D2 列表内排序走 `position` 字段，采用间隔策略

**Context**：
`media_item_shelves` 表已预留 `position` 字段（默认 0），但当前未使用。要实现手动排序，需要一种不频繁全表更新的策略。

**Decision**：
采用间隔插入策略（初始间隔 1000），仅在间隔耗尽时触发全表重排。

**Consequences**：
- 大部分排序操作只需更新单条记录的 position
- 极端频繁重排场景下可能触发全表重排，但概率低
- 不需要引入额外的排序表或链表结构

### D3 批量选择状态保持页面局部

**Context**：
批量选择是一种临时性的页面交互状态，不需要跨页面共享，也不需要持久化。

**Decision**：
批量选择状态用 `StatefulWidget` + 局部 controller 管理，不提升为全局 Riverpod provider。

**Consequences**：
- 页面卸载时批量状态自动重置
- 不需要担心状态泄漏
- Library 页和 List Detail 页的批量逻辑可以复用同一套 controller

### D4 列表删除级联软删除关联，不级联删除媒体条目

**Context**：
列表是组织容器，删除列表不应该删除列表内的媒体条目（它们仍可在 Library 中找到）。

**Decision**：
删除列表时，只软删除 `media_item_shelves` 关联记录，`media_items` 不受影响。

**Consequences**：
- 用户删除列表后，列表内的条目仍然保留在 Library 中
- 关联记录软删除后可被同步引擎追踪
- 如果用户需要同时删除条目本身，那是另一个操作（在 Library 或 Detail 页执行）

### D5 系统列表（kind = system）只读展示

**Context**：
当前 schema 中 `ShelfKind` 包含 `system` 类型，为未来预留（如"全部"、"已完成"等系统级视图列表）。

**Decision**：
本轮列表管理中心只管理用户自定义列表（`kind = user`）。系统列表如果存在，只读展示，不可编辑、不可删除。

**Consequences**：
- 如果未来引入系统列表，需要扩展 UI 以区分展示
- 当前阶段只处理用户列表，避免过度设计

---

## 实现计划

### PR1：列表中心页骨架

- 新增 `/lists` 路由和 sidebar 导航
- `lists_center_page.dart` + `shelf_card.dart`
- `ShelfDao` / `ShelfRepository` 新增 `watchAll(userOnly: true)` 和计数查询
- 列表中心空状态
- 创建列表对话框

### PR2：列表详情页与基础管理

- 新增 `/lists/detail/:id` 路由
- `list_detail_page.dart` + 排序选择器
- `ShelfDao` / `ShelfRepository` 新增按列表查条目、排序查询
- 重命名和删除功能
- 列表详情空状态

### PR3：批量操作与手动排序

- Library 页批量选择模式 + 加入列表功能
- 列表详情页批量选择模式 + 移出列表功能
- 手动排序 UI（拖拽或按钮）+ position 更新
- `batchAttach` / `batchDetach` / `reorderItems` 实现

### PR4：测试、文档与验收

- DAO / Repository 单元测试
- 页面 widget 测试
- `flutter analyze` 和 `flutter test` 通过
- `.trellis/spec/` 更新（如有新模式）
- 手工 Windows 桌面验证

---

## Out of Scope

- Bangumi 搜索、匹配、绑定、快捷添加
- WebDAV / S3-compatible 同步
- 跨设备同步（虽然表结构已预留字段，但本轮不实现 sync 逻辑）
- 协作列表 / 分享列表
- 智能推荐列表
- 列表封面拼图、复杂拖拽动画
- 列表描述、封面图片、颜色主题等额外元字段
- 系统列表的管理界面
- 海报上传、裁剪、本地图片管理
- 批量编辑条目属性（如批量改状态、评分）
- Rich review、重刷次数、长评系统
- 从 Home 页直接批量操作

---

## 依赖

- 依赖 `04-19-phase1-wp4-local-record-flow`（已完成）
- 依赖 WP4 已把 `ShelfRepository` 的最小链路接通
- 依赖现有 `PosterViewData`、`PosterWrap`、`PosterCard`、`EmptyState` 等共享组件

---

## 备注

这是后续增强任务，不阻塞 WP4 收口，也不阻塞阶段1最小本地闭环验收。

列表管理中心的视觉参考可对标 Stitch 的 collections / playlists 管理界面。若本地 HTML 缓存中没有对应参考，可先用 Library 页的视觉密度作为基准，保持一致的卡片尺度和间距节奏。
