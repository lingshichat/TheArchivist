# 阶段3-WP5：冲突副本与最小状态展示

## Goal

补齐阶段3最后一层可见性：

* 文本冲突副本
* 最小同步状态
* 设置页只读状态面板
* 阶段3回归测试

## Requirements

### R1 文本冲突副本

阶段3首版至少覆盖：

* `notes`
* `review`

冲突时：

* 不能静默覆盖
* 必须保留冲突副本
* 只要求记录副本与“存在冲突”摘要

### R2 最小同步状态模型

需要能稳定表达：

* 最近同步时间
* 当前是否正在同步
* 最近一次失败原因摘要
* 是否存在待处理冲突

### R3 设置页最小展示

把 `settings_page.dart` 里的 `Cloud Sync` 从占位文案升级成 provider 驱动的只读状态面板。

阶段3只展示：

* 当前状态
* 最近同步时间
* 最近失败摘要
* 是否有冲突

### R4 回归测试

至少覆盖：

* 文本冲突副本被保留
* 标量字段仍按最后修改优先
* 状态 provider 能正确反映 success / running / failure / conflict

## Acceptance Criteria

* [ ] `notes` / `review` 冲突会保留副本
* [ ] 最小同步状态可被 provider 消费
* [ ] 设置页 `Cloud Sync` 不再是静态占位文案
* [ ] 阶段3只展示最小状态，不提前做阶段4运维面板
* [ ] 冲突存在时用户能从设置页知道“有待处理冲突”
* [ ] `flutter analyze lib test` 通过
* [ ] 相关单元测试通过

## Technical Approach

* 冲突副本模型与存储放在 sync feature 范围内
* UI 只读消费 provider，不直接碰 repository / adapter
* 设置页继续保持轻量，避免提前侵入阶段4完整运维能力

## Out of Scope

* 冲突 diff 查看器
* 手动合并界面
* 待同步明细列表
* 手动重试中心
* 连接表单

## Technical Notes

### 依赖

* 依赖 `04-22-phase3-wp2-sync-engine-core`
* 设置页落点：`lib/features/settings/presentation/settings_page.dart`
