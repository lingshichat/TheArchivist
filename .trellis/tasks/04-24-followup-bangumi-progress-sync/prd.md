# 后续增强：Bangumi 进度同步

## 目标

补齐父任务 MVP 中“Bangumi 双向同步首批覆盖收藏状态、进度、评分”的进度同步缺口。

当前阶段2已经完成：

* Bangumi 搜索与快捷添加
* Bangumi 绑定
* 收藏状态同步
* 评分同步
* 首次导入、启动恢复回拉与手动 `Sync now`

本任务只承接“观看 / 阅读 / 游玩进度”同步，不重新打开阶段2已完成范围。

## 来源

来自 `04-18-flutter-media-tracker` 的任务树校准。

阶段2执行时，为控制范围，明确把剧集 / 页数 / 时长进度推送留到后续 follow-up。

## 范围

* 本地 `ProgressEntry` 到 Bangumi 的进度推送
* Bangumi 远端进度到本地的拉取与合并
* 媒介差异映射：
  * 影视：集数 / 剧集进度
  * 书籍：页数或章节进度
  * 游戏：游玩进度可表达范围内的映射
* 本地优先合并策略
* 同步失败轻提示与摘要记录
* 对现有 Bangumi 同步状态模型的最小扩展

## 不包含

* 私人笔记同步到 Bangumi
* 自定义标签同步到 Bangumi
* 自定义列表同步到 Bangumi
* 远端删除联动
* 复杂冲突处理中心
* WebDAV / S3-compatible 跨端同步配置

## 验收标准

* [ ] 修改本地进度后，已绑定且已映射 Bangumi subject 的条目可推送进度
* [ ] 手动 `Sync now` 可拉取 Bangumi 进度并合并到本地
* [ ] 本地存在脏改动时，远端进度不覆盖本地新值
* [ ] 同步失败不回滚本地进度
* [ ] 未绑定 Bangumi 时，本地进度链路不受影响
* [ ] 进度同步不污染 WebDAV / S3-compatible 跨端同步边界

## 依赖

* 依赖 `04-19-phase2-bangumi-flow`
* 依赖阶段1本地 `ProgressEntry` 链路

## 备注

这是 Bangumi 外部平台同步 follow-up。

它不属于当前 `04-19-phase4-settings-backup` 的设置、备份与同步运维范围。
