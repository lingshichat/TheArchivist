# 阶段3：跨端同步内核（WebDAV / S3-compatible）

## 目标

建立 Android 与 Windows 之间稳定的增量同步能力。

阶段3只解决“同一个应用数据在多设备之间一致”的问题。
它不替代 Bangumi 外部平台同步，也不依赖 Bangumi 账号。

## 前置依赖

* 强依赖 `04-19-phase1-local-core`
* 与 `04-19-phase2-bangumi-flow` 可部分并行
* 最终联调依赖阶段2完成，因为 Bangumi 条目也会携带 `sourceIdsJson`

## 范围

* 对象 / 日志同步模型
* 本地同步队列
* 增量上传与增量拉取
* 冲突判断
* `WebDAV` 适配器
* `S3-compatible` 适配器
* 同步状态最小记录

## 不包含

* 备份导入导出界面
* 同步设置向导细节
* 冲突副本人工处理界面
* Bangumi → 本地导入
* Bangumi 远端进度推送
* 完整同步运维 UI（留到阶段4）

## 父任务冻结边界

本阶段的长期契约归档到：

* `.trellis/spec/architecture/local-first-sync-contract.md`
* `.trellis/spec/architecture/system-boundaries.md`
* `.trellis/spec/backend/database-guidelines.md`

冻结规则：

* 本地数据库是运行时唯一真相源
* `WebDAV` / `S3-compatible` 只是存储和传输适配器
* 同步目标不负责冲突解决
* 日常跨设备同步走对象 / 日志增量
* 快照包只用于备份恢复，不用于日常自动同步
* 冲突判断和合并策略由应用自己维护
* 文本字段冲突必须保留冲突副本，不能静默覆盖

## Requirements

### R1 同步对象契约

同步对象必须具备：

* `updatedAt`
* `deletedAt`
* `syncVersion`
* `deviceId`
* `lastSyncedAt`

这些字段由 repository / sync 层维护。
页面层不得直接写入或推断这些字段。

### R2 增量同步模型

同步按对象或变更增量执行。

要求：

* 不同步整个数据库文件
* 上传只包含本机未同步或已变更对象
* 拉取只处理远端新增或更新对象
* soft delete 作为同步事件传播
* 同步失败可重试，不破坏本地状态

### R3 适配器边界

`WebDAV` 和 `S3-compatible` 适配器只负责：

* 认证 / 连接
* 对象列举
* 对象读取
* 对象写入
* 对象删除或 tombstone 写入

适配器不负责：

* 领域字段解释
* 冲突合并
* 状态映射
* activity log 语义

### R4 冲突策略

首版冲突处理采用：

* 默认最后修改优先
* 重要文本字段保留冲突副本

优先保留冲突副本的字段：

* 短评
* 私人笔记

可直接按最后修改覆盖的字段：

* 状态
* 评分
* 进度
* 列表 / 标签关联

### R5 状态可见但不打扰主流程

阶段3只要求最小状态可见：

* 最近同步时间
* 当前是否正在同步
* 最近一次失败原因摘要
* 是否存在待处理冲突

完整待同步列表、冲突查看和人工重试入口留到阶段4。

## 关键交付

* 两台设备可以通过相同同步目标完成稳定增量同步

## 验收标准

* [ ] 同步按对象或变更增量执行，不同步整库文件
* [ ] 同步对象具备 `updatedAt`、`deletedAt`、`syncVersion`、`deviceId`、`lastSyncedAt`
* [ ] `WebDAV` 和 `S3-compatible` 至少各有一个可用实现
* [ ] 状态、评分、进度、列表、标签可跨设备同步
* [ ] 文本字段冲突时保留冲突副本
* [ ] 同步失败不回滚本地数据
* [ ] 同步目标不可用时，应用仍可本地使用
* [ ] `flutter analyze lib test` 通过
* [ ] `flutter test` 通过

## 候选子任务拆分（阶段3启动时再创建）

为了保持任务树稳定，本 PRD 先冻结父任务契约，不预创建子任务。
阶段3真正启动时，再按下面候选拆分 child task：

1. 同步对象模型与本地队列
2. 增量上传 / 拉取引擎
3. WebDAV 适配器
4. S3-compatible 适配器
5. 冲突副本与最小状态展示

## 额外说明

* 同步目标只是存储介质，不是冲突解决器
* 同步逻辑必须由应用自己维护
* 若阶段3实现时发现需要改同步字段或冲突策略，必须同步更新本 PRD 和 `.trellis/spec/architecture/local-first-sync-contract.md`
