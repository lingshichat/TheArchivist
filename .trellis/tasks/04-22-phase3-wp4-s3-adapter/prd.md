# 阶段3-WP4：S3-compatible 适配器

## Goal

按阶段3父任务约定，实现一套可用的 `S3-compatible` storage adapter，供同步引擎复用。

## Requirements

### R1 对齐统一 adapter contract

必须复用阶段3统一 storage adapter contract，不允许单独做第二套 S3 引擎接口。

### R2 最小能力

至少支持：

* 认证 / 连接
* 列举对象
* 读取对象
* 写入对象
* 删除对象或写 tombstone

### R3 兼容 S3-compatible

适配器实现不能写死某一家云厂商，只能依赖阶段3约定的通用 S3-compatible 能力。

### R4 错误映射

需要把底层请求错误映射为同步域错误：

* 网络失败
* 认证失败
* 对象不存在
* 服务端失败

### R5 测试

至少覆盖：

* 正常 list / read / write / delete
* 认证失败
* 桶或前缀不存在
* 重复写入覆盖或幂等行为

## Acceptance Criteria

* [ ] S3-compatible 适配器复用统一 adapter contract
* [ ] list / read / write / delete / tombstone 能走通
* [ ] 不绑定某一家厂商私有语义
* [ ] 错误被映射为同步域错误，而不是原始 transport error
* [ ] fake 或 mock 测试覆盖关键成功 / 失败路径
* [ ] 不需要改引擎即可被 WP2 接入

## Technical Approach

* 适配器代码放在 `lib/features/sync/data/` 下
* bucket / prefix / endpoint 等传输细节由 adapter 吞掉，不泄漏到 UI 层
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
