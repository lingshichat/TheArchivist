# 阶段3-WP3：WebDAV 适配器

## Goal

按阶段3父任务约定，实现一套可用的 `WebDAV` storage adapter，供同步引擎复用。

## Requirements

### R1 对齐统一 adapter contract

必须复用阶段3统一 storage adapter contract，不允许单独发明 WebDAV 专用引擎接口。

### R2 最小能力

至少支持：

* 认证 / 连接
* 列举对象
* 读取对象
* 写入对象
* 删除对象或写 tombstone

### R3 错误映射

需要把底层 HTTP / I/O 错误映射为同步域错误：

* 网络失败
* 认证失败
* 资源不存在
* 服务端失败

### R4 路径与对象布局

适配器需要兼容阶段3统一远端对象布局，不得自己定义第二套目录结构。

### R5 测试

至少覆盖：

* 正常 list / read / write / delete
* 认证失败
* 路径不存在
* 重复写入覆盖或幂等行为

## Acceptance Criteria

* [ ] WebDAV 适配器复用统一 adapter contract
* [ ] list / read / write / delete / tombstone 能走通
* [ ] 错误被映射为同步域错误，而不是原始 transport error
* [ ] fake 或 mock 测试覆盖关键成功 / 失败路径
* [ ] 不需要改引擎即可被 WP2 接入

## Technical Approach

* 适配器代码放在 `lib/features/sync/data/` 下
* transport 细节可以抽小 client，但 provider 和 service 归 sync feature
* 凭据表单与连接测试 UI 不在本 WP

## Out of Scope

* 设置页表单
* 连接测试按钮
* 冲突处理
* 重试面板

## Technical Notes

### 依赖

* 依赖 `04-22-phase3-wp1-sync-model-queue`
* 接口联调依赖 `04-22-phase3-wp2-sync-engine-core`
