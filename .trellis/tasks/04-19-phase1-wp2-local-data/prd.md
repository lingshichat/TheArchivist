# 阶段1-WP2：本地数据模型与 Drift

## Goal

为阶段1建立本地持久化底座：引入 `drift`、定义 7 张核心表、暴露基础仓储层，让 WP3（页面骨架）和 WP4（记录动作）能消费稳定的本地数据。所有表结构一次性满足阶段2（Bangumi 外部映射）、阶段3（同步）的扩展需求。

## Requirements

### R1 Drift 基础设施

- 依赖：`drift`、`drift_flutter`（或等价 Windows/Android 双端方案）、`sqlite3_flutter_libs`、`path_provider`；dev：`build_runner`、`drift_dev`
- 数据库文件：`applicationSupportDirectory/record_anywhere.db`
- 目录：`lib/shared/data/{app_database.dart, tables/, daos/, repositories/}`
- Riverpod provider 暴露 `AppDatabase` 单例与各仓储

### R2 核心表结构（7 张表一次落齐）

所有业务表均带：`id TEXT (UUID v4)` / `createdAt` / `updatedAt` / `deletedAt` nullable / `syncVersion INTEGER` / `deviceId TEXT` / `lastSyncedAt` nullable

- `media_items`：条目主表
  - 共享字段：`mediaType`（枚举：movie / tv / book / game）/ `title` / `subtitle` / `posterUrl` / `releaseDate` / `overview` / `sourceIdsJson`（map<provider,id>）
  - 媒介特有可空字段：`runtimeMinutes` / `totalEpisodes` / `totalPages` / `estimatedPlayHours`
- `user_entries`：用户与条目关系
  - `mediaItemId` FK / `status`（统一枚举：wishlist / inProgress / done / onHold / dropped）/ `score` / `review` / `notes` / `favorite` / `reconsumeCount` / `startedAt` / `finishedAt`
  - 唯一约束：`(mediaItemId)` —— 每条目一条 UserEntry
- `progress_entries`：进度
  - `mediaItemId` FK / 按媒介可空：`currentEpisode` / `currentPage` / `currentMinutes` / `completionRatio`
- `tags`：用户自定义标签（`name` / `color` 可选）
- `shelf_lists`：系统列表 + 用户自定义列表（`name` / `kind`：`system` / `user`）
- `media_item_tags`：多对多 join（`mediaItemId` / `tagId` / 带同步字段）
- `media_item_shelves`：多对多 join（`mediaItemId` / `shelfListId` / `position` / 带同步字段）
- `activity_logs`：行为时间线（表建立，WP4 接入写入）
  - `mediaItemId` FK / `event` 枚举（statusChanged / scoreChanged / progressChanged / noteEdited / added / completed）/ `payloadJson`

索引：
- `media_items(mediaType, deletedAt)` 供库页筛选
- `user_entries(status, updatedAt DESC)` 供首页三段查询
- `user_entries(mediaItemId)` 唯一
- `activity_logs(mediaItemId, createdAt DESC)` 供详情页历史

### R3 仓储层（interface + Drift 实现）

- `MediaRepository`：
  - `Future<MediaItem> upsert(MediaItem)`
  - `Future<void> softDelete(String id)`
  - `Stream<List<MediaItemWithUserEntry>> watchContinuing({int limit})`
  - `Stream<List<MediaItemWithUserEntry>> watchRecentlyAdded({int limit})`
  - `Stream<List<MediaItemWithUserEntry>> watchRecentlyFinished({int limit})`
  - `Stream<List<MediaItemWithUserEntry>> watchLibrary({MediaType? type, UnifiedStatus? status, LibrarySort sort})`
  - `Stream<MediaItemDetail> watchDetail(String id)`（条目 + user entry + progress）
- `UserEntryRepository`：`updateStatus / updateScore / updateNotes / toggleFavorite`（每个方法在事务内刷新 `updatedAt` + `syncVersion` + `deviceId`）
- `ProgressRepository`：`updateProgress`（按媒介写入相应可空列，事务边界）
- `TagRepository` / `ShelfRepository`：基础 CRUD + `attach(mediaItemId, tagId)` / `detach`

### R4 设备标识

- `DeviceIdentityService`：首次启动生成 UUID v4 存入 `app_settings` 单行表（键值），后续读取
- 所有仓储写入经 `SyncStampDecorator` 自动注入：`updatedAt = now` / `syncVersion += 1` / `deviceId = current`

### R5 后端 spec 文档

- 填写 `.trellis/spec/backend/database-guidelines.md`：
  - Drift 使用约定（表命名、列命名、枚举 TypeConverter、迁移策略）
  - 软删除 + 同步戳记的统一模式
  - 仓储接口设计约定

### R6 测试

- 在 `test/` 下新增仓储单测（使用 `drift` 内存数据库），覆盖：
  - `MediaItem` + `UserEntry` 新建 / 更新 / 软删除后 `watchLibrary` 过滤正确
  - 首页三段查询顺序 / 条数 / status 过滤
  - 状态变更自动刷新 `updatedAt` / `syncVersion`
  - 进度按媒介写入正确可空列
  - 软删除后条目不可见但 `deletedAt` 已打标

## Acceptance Criteria

- [ ] `drift` + `build_runner` 配置就位，`dart run build_runner build --delete-conflicting-outputs` 生成代码成功
- [ ] 7 张表全部落地，所有业务表含 Phase 3 要求的同步字段
- [ ] UUID v4 主键 + 软删除语义就位
- [ ] 仓储层暴露 WP3/WP4 所需的 `watch*` 与原子更新方法
- [ ] 状态、评分、进度、私人笔记可独立持久化
- [ ] 外部 ID 通过 `sourceIdsJson` 预留，阶段2 可无 schema 改动直接挂接
- [ ] `device_id` 首次启动稳定生成，所有写入自动注入同步戳
- [ ] `.trellis/spec/backend/database-guidelines.md` 填写完成
- [ ] 内存数据库单元测试通过
- [ ] `flutter analyze` 与 `flutter test` 无错误

## Definition of Done

- 代码：Drift schema / 仓储 / providers / DeviceIdentityService 合入
- 测试：内存数据库单测通过；`flutter analyze` / `flutter test` 绿
- 文档：`database-guidelines.md` 填实本项目的 Drift 约定
- 生成产物：`.gitignore` 添加 `*.g.dart` / `*.drift.dart`；README 或本 PRD 注明首次拉取后需 `dart run build_runner build`
- 手工验证：通过一次性 smoke 脚本或单测跑通"新建 → 改状态 → 改进度 → 软删"主流程

## Technical Approach

### Schema 方向：Approach A

- 单 `media_items` 表 + `mediaType` 枚举 + 可空媒介特有字段
- 单 `progress_entries` 表 + 按媒介可空列
- 简单、少 join、与父 PRD 实体描述直接对应，与 Ryot / Drift 官方 example 一致

### 主键：UUID v4 TEXT

- 所有业务表主键为 36 字符 TEXT，应用层用 `Uuid` 包生成
- 全局唯一，阶段3 跨设备合并不需要重写引用
- 索引开销可接受（首版规模不大）

### 同步戳记：装饰器注入

- 仓储层不让 UI 关心 `updatedAt / syncVersion / deviceId` 的维护
- 写入方法在事务内调用 `SyncStampDecorator.stamp()`，保证原子

### 外部 ID：双轨预留

- 近期：`media_items.sourceIdsJson`（`{"bangumi": "123", "tmdb": "456"}`）
- 远期：阶段2 再加独立 `external_mappings` 表处理一对多 / episode 级映射；WP2 不建此表

### 生成产物策略

- `*.g.dart` / `*.drift.dart` 写入 `.gitignore`
- README 增加"首次拉取后需运行 `dart run build_runner build --delete-conflicting-outputs`"一句
- CI（未来）需加入 generate 步骤

## Decision (ADR-lite)

**Context**：
WP2 是阶段1 数据底座，必须服务 WP3/WP4 的即时需求，同时为阶段2/3 留扩展位。

**Decisions**：
1. **范围**：一次性落 7 张表（含 join + activity_logs 占位）
2. **Schema**：Approach A（单表 + 枚举 + 可空列）
3. **ID**：UUID v4 字符串主键
4. **生成产物**：`.gitignore`，开发者与 CI 自跑 build_runner
5. **同步字段**：所有业务表从第一天起带 `updatedAt / deletedAt / syncVersion / deviceId / lastSyncedAt`
6. **软删除**：统一用 `deletedAt` 标记；硬删除仅备份恢复路径使用（阶段4）
7. **外部 ID 近期方案**：`sourceIdsJson` 字段，阶段2 若不够用再升级到独立 `external_mappings` 表

**Consequences**：
- Schema 首次落地较重，但避免 WP3/WP4 期间反复改表
- UUID 索引略占空间，可接受
- 生成产物不入库，首次拉取体验多一步，但 diff 干净

## Implementation Plan (small PRs)

- **PR1 — 脚手架 + 空表**：
  - 加依赖 + `lib/shared/data/` 目录骨架
  - `AppDatabase` 启动 + 空表定义 + `DeviceIdentityService`
  - `.gitignore` 更新；README 增加 build_runner 说明
  - 跑通启动、生成代码、空数据库创建
- **PR2 — 核心表 + MediaRepository**：
  - `media_items` / `user_entries` / `progress_entries` + `SyncStampDecorator`
  - `MediaRepository` 完整实现（watch* 查询 + upsert/softDelete）
  - 单测覆盖首页三段、库页过滤
- **PR3 — tags / shelves / activity_logs + 收尾**：
  - 剩余 4 张表 + `TagRepository` / `ShelfRepository`
  - `activity_logs` 表结构建立，写入留占位 API
  - 填写 `database-guidelines.md`
  - 补充单测

## Out of Scope

- Bangumi API 对接与 `external_mappings` 独立表
- WebDAV / S3 同步、同步队列、冲突副本
- 备份导入导出、snapshot 包
- `MediaDetails` 深度元数据（genres / creators 等）的实际填充——本 WP 只建共享字段
- `ActivityLog` 自动写入链路（WP4 接）
- UI 切换到真实数据（WP3 联调）
- `MediaType = music` 等额外媒介（首版仅 movie/tv/book/game）

## Technical Notes

### 已阅读文件

- `.trellis/tasks/04-18-flutter-media-tracker/prd.md`
- `.trellis/tasks/04-19-phase1-local-core/prd.md`
- `.trellis/tasks/04-19-phase3-sync-engine/prd.md`
- `.trellis/tasks/04-19-phase1-wp3-windows-shell-pages/prd.md`
- `.trellis/tasks/04-19-phase1-wp4-local-record-flow/prd.md`
- `.trellis/spec/frontend/{directory-structure,state-management,quality-guidelines}.md`
- `.trellis/spec/backend/database-guidelines.md`（当前为空，本 WP 填实）
- `pubspec.yaml`、`lib/app/app.dart`、`lib/shared/demo/demo_data.dart`

### 约束来源

- 父 PRD § 5、§ 8.5.5
- 阶段3 PRD 硬约束同步字段
- 前端 state-management：UI 经 Riverpod 消费仓储

### 参考实现

- Ryot（Rust）：单 Metadata 表 + MetadataLot 枚举
- Drift 官方 examples：单表 + 枚举 + TypeConverter
