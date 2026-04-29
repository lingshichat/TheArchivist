# brainstorm: 项目方向梳理

## Goal

给 The Archivist 找一个下一步可做、能恢复手感、改动规模可控的产品方向。

目标不是扩大战线，而是从现有能力里挑一个能让应用更像“每天会打开的个人档案工具”的 MVP。

## What I already know

* 用户当前没有明确新需求，主要问题是对项目下一步缺少灵感。
* 当前没有 active task。
* 项目是 Windows-first Flutter 应用，核心定位是个人媒体档案工具。
* 已完成本地数据、详情编辑、Bangumi 搜索/添加/同步、进度同步、列表管理、WebDAV / S3-compatible 跨端同步、备份导入导出。
* 首页当前已有 Continuing、Recently Added、Recently Finished、Categories。
* Library 当前有媒体类型、状态、排序、批量加入列表，但没有关键词搜索、标签过滤、收藏入口。
* Detail 当前已有状态、评分、进度、公开短评、私有笔记、历史记录。
* 数据层已有 `favorite`、`reconsumeCount`、`communityScore`、`totalEpisodes`、`totalPages`、`estimatedPlayHours`、`progress`、`tags`、`shelf` 等字段。
* Sync conflict 已能记录冲突副本，但产品侧还缺少明确的冲突处理中心。
* README 仍是 Flutter 默认模板，不反映当前产品能力。

## Assumptions (temporary)

* 下一步应优先做一个小而完整的体验闭环。
* 不应先做重型新集成或大重构。
* 更适合补“使用动机”和“可见价值”，而不是继续堆底层能力。

## Open Questions

* 下一步选哪条方向作为 MVP？

## Requirements (evolving)

* 输出 2 到 4 个可落地方向。
* 每个方向说明价值、改动范围和风险。
* 选定方向后再收敛成可执行 PRD。

## Acceptance Criteria (evolving)

* [ ] 至少提出 3 个和现有代码能力匹配的产品方向。
* [ ] 每个方向有明确 MVP 边界。
* [ ] 用户选定一个方向后，PRD 能继续细化到实现计划。

## Definition of Done

* 测试按最终实现范围补充或更新。
* `flutter analyze` 无新增 error / warning。
* 若行为变化影响使用说明，更新 README 或相关 Trellis 记录。
* 若沉淀出长期规则，更新 `.trellis/spec/`。

## Out of Scope

* 暂不引入新的外部平台集成。
* 暂不做移动端适配。
* 暂不重做整体视觉系统。
* 暂不做跨端同步协议重构。

## Technical Notes

关键现有入口：

* `lib/features/home/data/home_view_data.dart`
* `lib/features/home/presentation/home_page.dart`
* `lib/features/library/data/library_view_data.dart`
* `lib/features/library/presentation/library_page.dart`
* `lib/features/detail/data/detail_view_data.dart`
* `lib/features/detail/presentation/detail_page.dart`
* `lib/features/settings/presentation/settings_page.dart`
* `lib/features/sync/data/sync_conflict.dart`
* `lib/shared/data/tables/user_entries.dart`
* `lib/shared/data/tables/progress_entries.dart`
* `lib/shared/data/tables/media_items.dart`

## Candidate Directions

### 方向 A：Today / Next Up 首页

把首页从展示型首页改成行动型首页。

MVP：

* 增加 “Next Up” 区块，优先展示 `inProgress` 且未完成的条目。
* 卡片上展示下一集 / 下一页 / 当前进度。
* 提供一个快速 `+1 episode` 或 “Mark Done” 操作。

价值：

* 用户每天打开应用有明确动作。
* 复用现有进度、状态、详情保存链路。

风险：

* 要把部分详情动作抽成首页可复用动作，避免 UI 直接写仓储。

### 方向 B：Library 搜索与筛选增强

把库页改成真正可找东西的档案入口。

MVP：

* 增加关键词搜索。
* 增加 Favorite 筛选。
* 增加 Tags / Lists 的轻量过滤入口，优先只做一个。

价值：

* 本地数据多起来后马上有用。
* 改动集中在 Library query、DAO / repository 查询和 UI 筛选条。

风险：

* 多筛选条件会让查询参数和测试组合膨胀，MVP 需要压住范围。

### 方向 C：Conflict Review Center

把同步冲突从“状态提示”变成可处理的收件箱。

MVP：

* Settings 里新增 “Review Conflicts” 入口。
* 展示 notes / review 的本地版本和远端版本。
* 提供 keep local / keep remote / copy text 后手动处理的最小流程。

价值：

* 补齐跨端同步最后一段可信度。
* 直接使用现有冲突副本存储。

风险：

* 需要定义 resolve 后如何更新主记录和冲突状态。

### 方向 D：Project Packaging / README / First-run polish

把项目从“能跑”打磨成“能交付演示”。

MVP：

* README 改成真实产品说明。
* 增加截图位、功能清单、运行方式、数据安全说明。
* 修复硬编码展示文案，例如 Library header 里的用户称呼。

价值：

* 成本低，能快速恢复项目完成感。
* 适合在大功能之间做一次收口。

风险：

* 产品功能增量较弱，可能不够有趣。

